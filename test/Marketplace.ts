import { expect } from 'chai';
import { network } from 'hardhat';

const { ethers } = await network.connect();

describe('Marketplace', function () {
  async function deployMarketplaceFixture() {
    // Get the signers (accounts) we'll use for testing
    const [owner, seller, buyer, admin, otherUser] = await ethers.getSigners();

    // Deploy the Marketplace contract
    const Marketplace = await ethers.getContractFactory('Marketplace');
    const marketplace = await Marketplace.deploy();

    return { marketplace, owner, seller, buyer, admin, otherUser };
  }

  async function listItemFixture() {
    const { marketplace, owner, seller, buyer, admin, otherUser } =
      await deployMarketplaceFixture();

    // List an item first (we need this for purchase tests)
    const itemName = 'Test Item';
    const itemDescription = 'A test item for purchasing';
    const itemPrice = ethers.parseEther('1.0');

    await marketplace
      .connect(seller)
      .listItem(itemName, itemDescription, itemPrice);

    return {
      marketplace,
      owner,
      seller,
      buyer,
      admin,
      otherUser,
      itemPrice,
      itemName,
      itemDescription,
    };
  }

  async function purchasedItemFixture() {
    const fixtures = await listItemFixture();
    const { marketplace, buyer, itemPrice } = fixtures;

    // Purchase the item
    await marketplace.connect(buyer).purchaseItem(1, { value: itemPrice });

    return fixtures;
  }

  async function shippedItemFixture() {
    const fixtures = await purchasedItemFixture();
    const { marketplace, seller } = fixtures;

    // Mark as shipped
    await marketplace.connect(seller).markAsShipped(1);

    return fixtures;
  }

  describe('Deployment', function () {
    it('Should set the deployer as initial admin', async function () {
      const { marketplace, owner } = await deployMarketplaceFixture();

      expect(await marketplace.admins(owner.address)).to.equal(true);
      console.log('Owner address is:', owner.address);
    });

    it('Should initialize counters to 0', async function () {
      const { marketplace } = await deployMarketplaceFixture();

      expect(await marketplace.itemCounter()).to.equal(0);
      expect(await marketplace.orderCounter()).to.equal(0);
      console.log('Initial item counter:', await marketplace.itemCounter());
      console.log('Initial order counter:', await marketplace.orderCounter());
    });
  });

  describe('Admin Management', function () {
    it('Should allow admin to add new admin', async function () {
      const { marketplace, owner, admin } = await deployMarketplaceFixture();

      // Check that admin is not an admin yet
      expect(await marketplace.admins(admin.address)).to.equal(false);

      // Owner (who is admin) adds new admin
      await marketplace.connect(owner).addAdmin(admin.address);

      // Check that admin is now an admin
      expect(await marketplace.admins(admin.address)).to.equal(true);
      console.log('New admin added:', admin.address);
    });

    it('Should emit AdminAdded event', async function () {
      const { marketplace, owner, admin } = await deployMarketplaceFixture();

      await expect(marketplace.connect(owner).addAdmin(admin.address))
        .to.emit(marketplace, 'AdminAdded')
        .withArgs(admin.address);
    });

    it('Should revert when non-admin tries to add admin', async function () {
      const { marketplace, seller, admin } = await deployMarketplaceFixture();

      await expect(
        marketplace.connect(seller).addAdmin(admin.address)
      ).to.be.revertedWithCustomError(marketplace, 'NotAdmin');
    });

    it('Should revert when trying to add zero address as admin', async function () {
      const { marketplace, owner } = await deployMarketplaceFixture();

      await expect(
        marketplace.connect(owner).addAdmin(ethers.ZeroAddress)
      ).to.be.revertedWith('Cannot add zero address as admin');
    });
  });

  describe('Item Listing', function () {
    it('Should allow users to list items', async function () {
      const { marketplace, seller } = await deployMarketplaceFixture();

      const itemName = 'Test Item';
      const itemDescription = 'A test item for testing';
      const itemPrice = ethers.parseEther('1.0'); // 1 ETH

      // List an item
      await marketplace
        .connect(seller)
        .listItem(itemName, itemDescription, itemPrice);

      // Check that item counter increased
      expect(await marketplace.itemCounter()).to.equal(1);

      // Get the item and verify its properties
      const item = await marketplace.getItem(1);
      expect(item.name).to.equal(itemName);
      expect(item.description).to.equal(itemDescription);
      expect(item.price).to.equal(itemPrice);
      expect(item.seller).to.equal(seller.address);
      expect(item.status).to.equal(0); // Available status

      console.log('Item listed successfully:', itemName);
      console.log('Item price:', ethers.formatEther(item.price), 'ETH');
    });

    it('Should emit ItemListed event', async function () {
      const { marketplace, seller } = await deployMarketplaceFixture();

      const itemName = 'Test Item';
      const itemDescription = 'A test item';
      const itemPrice = ethers.parseEther('1.0');

      await expect(
        marketplace
          .connect(seller)
          .listItem(itemName, itemDescription, itemPrice)
      )
        .to.emit(marketplace, 'ItemListed')
        .withArgs(1, seller.address);
    });

    it('Should revert when item name is empty', async function () {
      const { marketplace, seller } = await deployMarketplaceFixture();

      const emptyName = '';
      const itemDescription = 'A test item';
      const itemPrice = ethers.parseEther('1.0');

      await expect(
        marketplace
          .connect(seller)
          .listItem(emptyName, itemDescription, itemPrice)
      ).to.be.revertedWith('Item name cannot be empty');

      console.log('Empty name validation works correctly');
    });

    it('Should revert when item description is empty', async function () {
      const { marketplace, seller } = await deployMarketplaceFixture();

      const itemName = 'Test Item';
      const emptyDescription = '';
      const itemPrice = ethers.parseEther('1.0');

      await expect(
        marketplace
          .connect(seller)
          .listItem(itemName, emptyDescription, itemPrice)
      ).to.be.revertedWith('Item description cannot be empty');

      console.log('Empty description validation works correctly');
    });

    it('Should revert when price is zero', async function () {
      const { marketplace, seller } = await deployMarketplaceFixture();

      const itemName = 'Test Item';
      const itemDescription = 'A test item';
      const zeroPrice = 0;

      await expect(
        marketplace
          .connect(seller)
          .listItem(itemName, itemDescription, zeroPrice)
      ).to.be.revertedWithCustomError(marketplace, 'PriceTooLow');

      console.log('Zero price validation works correctly');
    });

    it("Should add item to user's items array", async function () {
      const { marketplace, seller } = await deployMarketplaceFixture();

      const itemName = 'Test Item';
      const itemDescription = 'A test item';
      const itemPrice = ethers.parseEther('1.0');

      await marketplace
        .connect(seller)
        .listItem(itemName, itemDescription, itemPrice);

      // Check that the item was added to userItems mapping
      const userItem = await marketplace.userItems(seller.address, 0);
      expect(userItem).to.equal(1);
    });
  });

  describe('Item Purchasing', function () {
    it('Should allow buyers to purchase items', async function () {
      const { marketplace, seller, buyer, itemPrice } = await listItemFixture();

      // Check initial order counter
      expect(await marketplace.orderCounter()).to.equal(0);

      // Purchase the item
      await marketplace.connect(buyer).purchaseItem(1, { value: itemPrice });

      // Check that order counter increased
      expect(await marketplace.orderCounter()).to.equal(1);

      // Check that item status changed to Sold (1)
      const item = await marketplace.getItem(1);
      expect(item.status).to.equal(1); // Sold

      // Check that order was created correctly
      const order = await marketplace.orders(1);
      expect(order.itemId).to.equal(1);
      expect(order.buyer).to.equal(buyer.address);
      expect(order.seller).to.equal(seller.address);
      expect(order.amount).to.equal(itemPrice);
      expect(order.status).to.equal(0); // Pending

      console.log('Item purchased successfully by:', buyer.address);
      console.log('Escrow amount:', ethers.formatEther(order.amount), 'ETH');
    });

    it('Should emit OrderCreated event', async function () {
      const { marketplace, seller, buyer, itemPrice } = await listItemFixture();

      await expect(
        marketplace.connect(buyer).purchaseItem(1, { value: itemPrice })
      )
        .to.emit(marketplace, 'OrderCreated')
        .withArgs(1, 1, buyer.address, seller.address);
    });

    it('Should prevent seller from buying their own item', async function () {
      const { marketplace, seller, itemPrice } = await listItemFixture();

      // Seller tries to buy their own item (should fail)
      await expect(
        marketplace.connect(seller).purchaseItem(1, { value: itemPrice })
      ).to.be.revertedWithCustomError(marketplace, 'SelfPurchase');

      console.log('Self-purchase prevention works correctly');
    });

    it('Should reject incorrect payment amounts', async function () {
      const { marketplace, buyer, itemPrice } = await listItemFixture();

      const wrongPrice = ethers.parseEther('0.5'); // Wrong amount (0.5 ETH instead of 1.0)

      // Try to pay wrong amount (should fail)
      await expect(
        marketplace.connect(buyer).purchaseItem(1, { value: wrongPrice })
      ).to.be.revertedWithCustomError(marketplace, 'IncorrectPayment');

      console.log('Incorrect payment rejection works correctly');
    });

    it('Should prevent purchasing unavailable items', async function () {
      const { marketplace, buyer, admin, itemPrice } = await listItemFixture();

      // First, buy the item normally
      await marketplace.connect(buyer).purchaseItem(1, { value: itemPrice });

      // Now try to buy it again (should fail because it's already sold)
      await expect(
        marketplace.connect(admin).purchaseItem(1, { value: itemPrice })
      ).to.be.revertedWithCustomError(marketplace, 'ItemNotAvailable');

      console.log('Double purchase prevention works correctly');
    });

    it('Should reject invalid item IDs', async function () {
      const { marketplace, buyer, itemPrice } = await listItemFixture();

      // Try to buy item that doesn't exist
      await expect(
        marketplace.connect(buyer).purchaseItem(999, { value: itemPrice })
      ).to.be.revertedWith('Invalid item ID');

      console.log('Invalid item ID rejection works correctly');
    });
  });

  describe('Order Management', function () {
    describe('Mark as Shipped', function () {
      it('Should allow seller to mark order as shipped', async function () {
        const { marketplace, seller } = await purchasedItemFixture();

        await marketplace.connect(seller).markAsShipped(1);

        const order = await marketplace.orders(1);
        expect(order.status).to.equal(1); // Shipped
        console.log('Order marked as shipped successfully');
      });

      it('Should emit ItemShipped event', async function () {
        const { marketplace, seller } = await purchasedItemFixture();

        await expect(marketplace.connect(seller).markAsShipped(1))
          .to.emit(marketplace, 'ItemShipped')
          .withArgs(1);
      });

      it('Should revert if not seller', async function () {
        const { marketplace, buyer } = await purchasedItemFixture();

        await expect(
          marketplace.connect(buyer).markAsShipped(1)
        ).to.be.revertedWithCustomError(marketplace, 'UnauthorizedSeller');
      });

      it('Should revert if order not pending', async function () {
        const { marketplace, seller } = await purchasedItemFixture();

        await marketplace.connect(seller).markAsShipped(1);

        // Try to ship again
        await expect(
          marketplace.connect(seller).markAsShipped(1)
        ).to.be.revertedWithCustomError(marketplace, 'OrderNotPending');
      });

      it('Should revert for invalid order ID', async function () {
        const { marketplace, seller } = await purchasedItemFixture();

        await expect(
          marketplace.connect(seller).markAsShipped(999)
        ).to.be.revertedWith('Invalid order ID');
      });
    });

    describe('Confirm Receipt', function () {
      it('Should allow buyer to confirm receipt and release payment', async function () {
        const { marketplace, seller, buyer, itemPrice } =
          await shippedItemFixture();

        const initialBalance = await ethers.provider.getBalance(seller.address);

        await marketplace.connect(buyer).confirmReceipt(1);

        const finalBalance = await ethers.provider.getBalance(seller.address);
        expect(finalBalance - initialBalance).to.equal(itemPrice);

        const order = await marketplace.orders(1);
        expect(order.status).to.equal(2); // Delivered

        console.log(
          'Payment released to seller:',
          ethers.formatEther(itemPrice),
          'ETH'
        );
      });

      it('Should emit OrderCompleted event', async function () {
        const { marketplace, seller, buyer, itemPrice } =
          await shippedItemFixture();

        await expect(marketplace.connect(buyer).confirmReceipt(1))
          .to.emit(marketplace, 'OrderCompleted')
          .withArgs(1, seller.address, itemPrice);
      });

      it('Should revert if not buyer', async function () {
        const { marketplace, seller } = await shippedItemFixture();

        await expect(
          marketplace.connect(seller).confirmReceipt(1)
        ).to.be.revertedWithCustomError(marketplace, 'UnauthorizedBuyer');
      });

      it('Should revert if item not shipped', async function () {
        const { marketplace, buyer } = await purchasedItemFixture();

        await expect(
          marketplace.connect(buyer).confirmReceipt(1)
        ).to.be.revertedWithCustomError(marketplace, 'ItemNotShipped');
      });
    });

    describe('Cancel Order', function () {
      it('Should allow buyer to cancel pending order', async function () {
        const { marketplace, buyer, itemPrice } = await purchasedItemFixture();

        const initialBalance = await ethers.provider.getBalance(buyer.address);

        const tx = await marketplace.connect(buyer).cancelOrder(1);
        const receipt = await tx.wait();
        const gasUsed = receipt!.gasUsed * receipt!.gasPrice;

        const finalBalance = await ethers.provider.getBalance(buyer.address);
        expect(finalBalance + gasUsed - initialBalance).to.equal(itemPrice);

        const order = await marketplace.orders(1);
        expect(order.status).to.equal(3); // Cancelled

        // Item should be available again
        const item = await marketplace.getItem(1);
        expect(item.status).to.equal(0); // Available

        console.log('Order cancelled and refund processed');
      });

      it('Should emit OrderCancelled event', async function () {
        const { marketplace, buyer, itemPrice } = await purchasedItemFixture();

        await expect(marketplace.connect(buyer).cancelOrder(1))
          .to.emit(marketplace, 'OrderCancelled')
          .withArgs(1, buyer.address, itemPrice);
      });

      it('Should revert if not buyer', async function () {
        const { marketplace, seller } = await purchasedItemFixture();

        await expect(
          marketplace.connect(seller).cancelOrder(1)
        ).to.be.revertedWithCustomError(marketplace, 'UnauthorizedBuyer');
      });

      it('Should revert if order not pending', async function () {
        const { marketplace, seller, buyer } = await purchasedItemFixture();

        await marketplace.connect(seller).markAsShipped(1);

        await expect(
          marketplace.connect(buyer).cancelOrder(1)
        ).to.be.revertedWithCustomError(marketplace, 'OrderNotPending');
      });
    });
  });

  describe('Dispute Management', function () {
    describe('Raise Dispute', function () {
      it('Should allow buyer to raise dispute on shipped item', async function () {
        const { marketplace, buyer } = await shippedItemFixture();

        await marketplace.connect(buyer).raiseDispute(1);

        const order = await marketplace.orders(1);
        expect(order.status).to.equal(4); // Disputed

        console.log('Dispute raised successfully by buyer');
      });

      it('Should allow seller to raise dispute on shipped item', async function () {
        const { marketplace, seller } = await shippedItemFixture();

        await marketplace.connect(seller).raiseDispute(1);

        const order = await marketplace.orders(1);
        expect(order.status).to.equal(4); // Disputed

        console.log('Dispute raised successfully by seller');
      });

      it('Should emit DisputeRaised event', async function () {
        const { marketplace, buyer } = await shippedItemFixture();

        await expect(marketplace.connect(buyer).raiseDispute(1))
          .to.emit(marketplace, 'DisputeRaised')
          .withArgs(1, buyer.address);
      });

      it('Should revert if unauthorized user tries to raise dispute', async function () {
        const { marketplace, otherUser } = await shippedItemFixture();

        await expect(
          marketplace.connect(otherUser).raiseDispute(1)
        ).to.be.revertedWithCustomError(marketplace, 'UnauthorizedDispute');
      });

      it('Should revert if item not shipped', async function () {
        const { marketplace, buyer } = await purchasedItemFixture();

        await expect(
          marketplace.connect(buyer).raiseDispute(1)
        ).to.be.revertedWithCustomError(marketplace, 'ItemNotShipped');
      });
    });

    describe('Resolve Dispute', function () {
      async function disputedItemFixture() {
        const fixtures = await shippedItemFixture();
        const { marketplace, buyer } = fixtures;

        await marketplace.connect(buyer).raiseDispute(1);

        return fixtures;
      }

      it('Should allow admin to resolve dispute in favor of buyer', async function () {
        const { marketplace, owner, buyer, itemPrice } =
          await disputedItemFixture();

        const initialBalance = await ethers.provider.getBalance(buyer.address);

        await marketplace.connect(owner).resolveDispute(1, true);

        const finalBalance = await ethers.provider.getBalance(buyer.address);
        expect(finalBalance - initialBalance).to.equal(itemPrice);

        const order = await marketplace.orders(1);
        expect(order.status).to.equal(3); // Cancelled

        console.log('Dispute resolved in favor of buyer');
      });

      it('Should allow admin to resolve dispute in favor of seller', async function () {
        const { marketplace, owner, seller, itemPrice } =
          await disputedItemFixture();

        const initialBalance = await ethers.provider.getBalance(seller.address);

        await marketplace.connect(owner).resolveDispute(1, false);

        const finalBalance = await ethers.provider.getBalance(seller.address);
        expect(finalBalance - initialBalance).to.equal(itemPrice);

        const order = await marketplace.orders(1);
        expect(order.status).to.equal(2); // Delivered

        console.log('Dispute resolved in favor of seller');
      });

      it('Should emit DisputeResolved event', async function () {
        const { marketplace, owner, buyer, itemPrice } =
          await disputedItemFixture();

        await expect(marketplace.connect(owner).resolveDispute(1, true))
          .to.emit(marketplace, 'DisputeResolved')
          .withArgs(1, buyer.address, itemPrice);
      });

      it('Should revert if not admin', async function () {
        const { marketplace, buyer } = await disputedItemFixture();

        await expect(
          marketplace.connect(buyer).resolveDispute(1, true)
        ).to.be.revertedWithCustomError(marketplace, 'NotAdmin');
      });

      it('Should revert if order not in dispute', async function () {
        const { marketplace, owner } = await shippedItemFixture();

        await expect(
          marketplace.connect(owner).resolveDispute(1, true)
        ).to.be.revertedWithCustomError(marketplace, 'OrderNotInDispute');
      });
    });
  });

  describe('Utility Functions', function () {
    it('Should return correct order count with assert checks', async function () {
      const { marketplace } = await deployMarketplaceFixture();

      expect(await marketplace.getOrderCount()).to.equal(0);

      // Create an order
      const { marketplace: marketplace2 } = await purchasedItemFixture();
      expect(await marketplace2.getOrderCount()).to.equal(1);

      console.log('Assert checks in getOrderCount work correctly');
    });

    it('Should return item details correctly', async function () {
      const { marketplace, itemName, itemDescription, itemPrice } =
        await listItemFixture();

      const item = await marketplace.getItem(1);
      expect(item.name).to.equal(itemName);
      expect(item.description).to.equal(itemDescription);
      expect(item.price).to.equal(itemPrice);
    });

    it('Should revert getItem for invalid ID', async function () {
      const { marketplace } = await deployMarketplaceFixture();

      await expect(marketplace.getItem(999)).to.be.revertedWith(
        'Invalid item ID'
      );
    });
  });

  describe('Fallback and Receive Functions', function () {
    it('Should handle direct ETH transfers via receive', async function () {
      const { marketplace, buyer } = await deployMarketplaceFixture();

      const tx = {
        to: await marketplace.getAddress(),
        value: ethers.parseEther('1.0'),
      };

      await expect(buyer.sendTransaction(tx))
        .to.emit(marketplace, 'UnexpectedPayment')
        .withArgs(buyer.address, ethers.parseEther('1.0'));

      console.log('Receive function handles direct ETH transfers');
    });

    it('Should revert on unknown function calls', async function () {
      const { marketplace, buyer } = await deployMarketplaceFixture();

      const unknownFunction = '0x12345678'; // Random function selector

      await expect(
        buyer.sendTransaction({
          to: await marketplace.getAddress(),
          data: unknownFunction,
        })
      ).to.be.revertedWith('Function does not exist');

      console.log('Fallback function correctly rejects unknown calls');
    });
  });

  describe('Edge Cases and Security', function () {
    it('Should handle multiple items from same seller', async function () {
      const { marketplace, seller } = await deployMarketplaceFixture();

      await marketplace
        .connect(seller)
        .listItem('Item 1', 'First item', ethers.parseEther('1.0'));
      await marketplace
        .connect(seller)
        .listItem('Item 2', 'Second item', ethers.parseEther('2.0'));

      expect(await marketplace.itemCounter()).to.equal(2);

      const userItem1 = await marketplace.userItems(seller.address, 0);
      const userItem2 = await marketplace.userItems(seller.address, 1);

      expect(userItem1).to.equal(1);
      expect(userItem2).to.equal(2);

      console.log('Multiple items per seller handled correctly');
    });

    it('Should handle contract balance correctly during escrow', async function () {
      const { marketplace, itemPrice } = await purchasedItemFixture();

      const contractBalance = await ethers.provider.getBalance(
        await marketplace.getAddress()
      );
      expect(contractBalance).to.equal(itemPrice);

      console.log('Contract holds escrow funds correctly');
    });

    it('Should maintain correct order state transitions', async function () {
      const { marketplace, seller, buyer } = await purchasedItemFixture();

      let order = await marketplace.orders(1);
      expect(order.status).to.equal(0); // Pending

      await marketplace.connect(seller).markAsShipped(1);
      order = await marketplace.orders(1);
      expect(order.status).to.equal(1); // Shipped

      await marketplace.connect(buyer).confirmReceipt(1);
      order = await marketplace.orders(1);
      expect(order.status).to.equal(2); // Delivered

      console.log('Order state transitions work correctly');
    });
  });
});
