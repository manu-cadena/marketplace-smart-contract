import { expect } from 'chai';
import { network } from 'hardhat';

const { ethers } = await network.connect();

describe('Marketplace', function () {
  async function deployMarketplaceFixture() {
    // Get the signers (accounts) we'll use for testing
    const [owner, seller, buyer, admin] = await ethers.getSigners();

    // Deploy the Marketplace contract
    const Marketplace = await ethers.getContractFactory('Marketplace');
    const marketplace = await Marketplace.deploy();

    return { marketplace, owner, seller, buyer, admin };
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
  });
});
