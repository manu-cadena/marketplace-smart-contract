// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { Marketplace } from "../src/Marketplace.sol";

contract MarketplaceTest is Test {
    Marketplace public marketplace;
    
    // Test accounts
    address public owner;
    address public seller;
    address public buyer;
    address public admin;
    address public otherUser;
    
    // Test data
    string constant ITEM_NAME = "Test Item";
    string constant ITEM_DESCRIPTION = "A test item for testing";
    uint256 constant ITEM_PRICE = 1 ether;
    
    function setUp() public {
        // Set up test accounts
        owner = address(this);
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        admin = makeAddr("admin");
        otherUser = makeAddr("otherUser");
        
        // Give test accounts some ETH
        vm.deal(seller, 10 ether);
        vm.deal(buyer, 10 ether);
        vm.deal(admin, 10 ether);
        vm.deal(otherUser, 10 ether);
        
        // Deploy contract
        marketplace = new Marketplace();
    }
    
    // Helper function to list an item
    function _listItem() internal returns (uint256 itemId) {
        vm.prank(seller);
        marketplace.listItem(ITEM_NAME, ITEM_DESCRIPTION, ITEM_PRICE);
        return marketplace.itemCounter();
    }
    
    // Helper function to purchase an item
    function _purchaseItem(uint256 itemId) internal returns (uint256 orderId) {
        vm.prank(buyer);
        marketplace.purchaseItem{value: ITEM_PRICE}(itemId);
        return marketplace.orderCounter();
    }
    
    // Helper function to ship an item
    function _shipItem(uint256 orderId) internal {
        vm.prank(seller);
        marketplace.markAsShipped(orderId);
    }
    
    // =================
    // DEPLOYMENT TESTS
    // =================
    
    function test_DeployerIsInitialAdmin() public view {
        assertTrue(marketplace.admins(owner));
    }
    
    function test_InitializeCountersToZero() public view {
        assertEq(marketplace.itemCounter(), 0);
        assertEq(marketplace.orderCounter(), 0);
    }
    
    // ===================
    // ADMIN MANAGEMENT
    // ===================
    
    function test_AdminCanAddNewAdmin() public {
        assertFalse(marketplace.admins(admin));
        
        marketplace.addAdmin(admin);
        
        assertTrue(marketplace.admins(admin));
    }
    
    function test_AddAdminEmitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit Marketplace.AdminAdded(admin);
        
        marketplace.addAdmin(admin);
    }
    
    function test_NonAdminCannotAddAdmin() public {
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.NotAdmin.selector, seller));
        marketplace.addAdmin(admin);
    }
    
    function test_CannotAddZeroAddressAsAdmin() public {
        vm.expectRevert("Cannot add zero address as admin");
        marketplace.addAdmin(address(0));
    }
    
    // ================
    // ITEM LISTING
    // ================
    
    function test_UsersCanListItems() public {
        vm.prank(seller);
        marketplace.listItem(ITEM_NAME, ITEM_DESCRIPTION, ITEM_PRICE);
        
        assertEq(marketplace.itemCounter(), 1);
        
        Marketplace.Item memory item = marketplace.getItem(1);
        assertEq(item.name, ITEM_NAME);
        assertEq(item.description, ITEM_DESCRIPTION);
        assertEq(item.price, ITEM_PRICE);
        assertEq(item.seller, seller);
        assertEq(uint(item.status), uint(Marketplace.ItemStatus.Available));
    }
    
    function test_ListItemEmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit Marketplace.ItemListed(1, seller);
        
        vm.prank(seller);
        marketplace.listItem(ITEM_NAME, ITEM_DESCRIPTION, ITEM_PRICE);
    }
    
    function test_EmptyNameReverts() public {
        vm.prank(seller);
        vm.expectRevert("Item name cannot be empty");
        marketplace.listItem("", ITEM_DESCRIPTION, ITEM_PRICE);
    }
    
    function test_EmptyDescriptionReverts() public {
        vm.prank(seller);
        vm.expectRevert("Item description cannot be empty");
        marketplace.listItem(ITEM_NAME, "", ITEM_PRICE);
    }
    
    function test_ZeroPriceReverts() public {
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.PriceTooLow.selector, 0));
        marketplace.listItem(ITEM_NAME, ITEM_DESCRIPTION, 0);
    }
    
    function test_ItemAddedToUserItemsArray() public {
        vm.prank(seller);
        marketplace.listItem(ITEM_NAME, ITEM_DESCRIPTION, ITEM_PRICE);
        
        uint256 userItemId = marketplace.userItems(seller, 0);
        assertEq(userItemId, 1);
    }
    
    // =================
    // ITEM PURCHASING
    // =================
    
    function test_BuyersCanPurchaseItems() public {
        uint256 itemId = _listItem();
        
        assertEq(marketplace.orderCounter(), 0);
        
        vm.prank(buyer);
        marketplace.purchaseItem{value: ITEM_PRICE}(itemId);
        
        assertEq(marketplace.orderCounter(), 1);
        
        // Check item status changed to Sold
        Marketplace.Item memory item = marketplace.getItem(itemId);
        assertEq(uint(item.status), uint(Marketplace.ItemStatus.Sold));
        
        // Check order was created correctly
        (
            uint256 orderItemId,
            address orderBuyer,
            address orderSeller,
            uint256 orderAmount,
            Marketplace.OrderStatus orderStatus,
            
        ) = marketplace.orders(1);
        assertEq(orderItemId, itemId);
        assertEq(orderBuyer, buyer);
        assertEq(orderSeller, seller);
        assertEq(orderAmount, ITEM_PRICE);
        assertEq(uint(orderStatus), uint(Marketplace.OrderStatus.Pending));
    }
    
    function test_PurchaseEmitsOrderCreatedEvent() public {
        uint256 itemId = _listItem();
        
        vm.expectEmit(true, true, true, true);
        emit Marketplace.OrderCreated(1, itemId, buyer, seller);
        
        vm.prank(buyer);
        marketplace.purchaseItem{value: ITEM_PRICE}(itemId);
    }
    
    function test_SellerCannotBuyOwnItem() public {
        uint256 itemId = _listItem();
        
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.SelfPurchase.selector));
        marketplace.purchaseItem{value: ITEM_PRICE}(itemId);
    }
    
    function test_IncorrectPaymentReverts() public {
        uint256 itemId = _listItem();
        
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.IncorrectPayment.selector, 0.5 ether, ITEM_PRICE));
        marketplace.purchaseItem{value: 0.5 ether}(itemId);
    }
    
    function test_CannotPurchaseUnavailableItem() public {
        uint256 itemId = _listItem();
        
        // First purchase
        vm.prank(buyer);
        marketplace.purchaseItem{value: ITEM_PRICE}(itemId);
        
        // Second purchase should fail
        vm.prank(otherUser);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.ItemNotAvailable.selector, itemId));
        marketplace.purchaseItem{value: ITEM_PRICE}(itemId);
    }
    
    function test_InvalidItemIdReverts() public {
        vm.prank(buyer);
        vm.expectRevert("Invalid item ID");
        marketplace.purchaseItem{value: ITEM_PRICE}(999);
    }
    
    // =================
    // ORDER MANAGEMENT
    // =================
    
    function test_SellerCanMarkAsShipped() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        
        vm.prank(seller);
        marketplace.markAsShipped(orderId);
        
        (
            ,
            ,
            ,
            ,
            Marketplace.OrderStatus orderStatus,
            
        ) = marketplace.orders(orderId);
        assertEq(uint(orderStatus), uint(Marketplace.OrderStatus.Shipped));
    }
    
    function test_MarkAsShippedEmitsEvent() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        
        vm.expectEmit(true, false, false, false);
        emit Marketplace.ItemShipped(orderId);
        
        vm.prank(seller);
        marketplace.markAsShipped(orderId);
    }
    
    function test_OnlySellerCanMarkAsShipped() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.UnauthorizedSeller.selector, buyer));
        marketplace.markAsShipped(orderId);
    }
    
    function test_CanOnlyShipPendingOrders() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        
        vm.prank(seller);
        marketplace.markAsShipped(orderId);
        
        // Try to ship again
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.OrderNotPending.selector, orderId));
        marketplace.markAsShipped(orderId);
    }
    
    function test_BuyerCanConfirmReceipt() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        _shipItem(orderId);
        
        uint256 initialBalance = seller.balance;
        
        vm.prank(buyer);
        marketplace.confirmReceipt(orderId);
        
        uint256 finalBalance = seller.balance;
        assertEq(finalBalance - initialBalance, ITEM_PRICE);
        
        (
            ,
            ,
            ,
            ,
            Marketplace.OrderStatus orderStatus,
            
        ) = marketplace.orders(orderId);
        assertEq(uint(orderStatus), uint(Marketplace.OrderStatus.Delivered));
    }
    
    function test_ConfirmReceiptEmitsEvent() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        _shipItem(orderId);
        
        vm.expectEmit(true, true, false, true);
        emit Marketplace.OrderCompleted(orderId, seller, ITEM_PRICE);
        
        vm.prank(buyer);
        marketplace.confirmReceipt(orderId);
    }
    
    function test_OnlyBuyerCanConfirmReceipt() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        _shipItem(orderId);
        
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.UnauthorizedBuyer.selector, seller));
        marketplace.confirmReceipt(orderId);
    }
    
    function test_CanOnlyConfirmShippedItems() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.ItemNotShipped.selector, orderId));
        marketplace.confirmReceipt(orderId);
    }
    
    function test_BuyerCanCancelPendingOrder() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        
        uint256 initialBalance = buyer.balance;
        
        vm.prank(buyer);
        marketplace.cancelOrder(orderId);
        
        uint256 finalBalance = buyer.balance;
        assertEq(finalBalance - initialBalance, ITEM_PRICE);
        
        (
            ,
            ,
            ,
            ,
            Marketplace.OrderStatus orderStatus,
            
        ) = marketplace.orders(orderId);
        assertEq(uint(orderStatus), uint(Marketplace.OrderStatus.Cancelled));
        
        // Item should be available again
        Marketplace.Item memory item = marketplace.getItem(itemId);
        assertEq(uint(item.status), uint(Marketplace.ItemStatus.Available));
    }
    
    function test_CancelOrderEmitsEvent() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        
        vm.expectEmit(true, true, false, true);
        emit Marketplace.OrderCancelled(orderId, buyer, ITEM_PRICE);
        
        vm.prank(buyer);
        marketplace.cancelOrder(orderId);
    }
    
    function test_OnlyBuyerCanCancelOrder() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.UnauthorizedBuyer.selector, seller));
        marketplace.cancelOrder(orderId);
    }
    
    function test_CanOnlyCancelPendingOrders() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        _shipItem(orderId);
        
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.OrderNotPending.selector, orderId));
        marketplace.cancelOrder(orderId);
    }
    
    // ==================
    // DISPUTE MANAGEMENT
    // ==================
    
    function test_BuyerCanRaiseDispute() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        _shipItem(orderId);
        
        vm.prank(buyer);
        marketplace.raiseDispute(orderId);
        
        (
            ,
            ,
            ,
            ,
            Marketplace.OrderStatus orderStatus,
            
        ) = marketplace.orders(orderId);
        assertEq(uint(orderStatus), uint(Marketplace.OrderStatus.Disputed));
    }
    
    function test_SellerCanRaiseDispute() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        _shipItem(orderId);
        
        vm.prank(seller);
        marketplace.raiseDispute(orderId);
        
        (
            ,
            ,
            ,
            ,
            Marketplace.OrderStatus orderStatus,
            
        ) = marketplace.orders(orderId);
        assertEq(uint(orderStatus), uint(Marketplace.OrderStatus.Disputed));
    }
    
    function test_RaiseDisputeEmitsEvent() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        _shipItem(orderId);
        
        vm.expectEmit(true, true, false, false);
        emit Marketplace.DisputeRaised(orderId, buyer);
        
        vm.prank(buyer);
        marketplace.raiseDispute(orderId);
    }
    
    function test_UnauthorizedUserCannotRaiseDispute() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        _shipItem(orderId);
        
        vm.prank(otherUser);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.UnauthorizedDispute.selector, otherUser));
        marketplace.raiseDispute(orderId);
    }
    
    function test_CanOnlyDisputeShippedItems() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.ItemNotShipped.selector, orderId));
        marketplace.raiseDispute(orderId);
    }
    
    function test_AdminCanResolveDisputeInFavorOfBuyer() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        _shipItem(orderId);
        
        vm.prank(buyer);
        marketplace.raiseDispute(orderId);
        
        uint256 initialBalance = buyer.balance;
        
        marketplace.resolveDispute(orderId, true);
        
        uint256 finalBalance = buyer.balance;
        assertEq(finalBalance - initialBalance, ITEM_PRICE);
        
        (
            ,
            ,
            ,
            ,
            Marketplace.OrderStatus orderStatus,
            
        ) = marketplace.orders(orderId);
        assertEq(uint(orderStatus), uint(Marketplace.OrderStatus.Cancelled));
    }
    
    function test_AdminCanResolveDisputeInFavorOfSeller() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        _shipItem(orderId);
        
        vm.prank(buyer);
        marketplace.raiseDispute(orderId);
        
        uint256 initialBalance = seller.balance;
        
        marketplace.resolveDispute(orderId, false);
        
        uint256 finalBalance = seller.balance;
        assertEq(finalBalance - initialBalance, ITEM_PRICE);
        
        (
            ,
            ,
            ,
            ,
            Marketplace.OrderStatus orderStatus,
            
        ) = marketplace.orders(orderId);
        assertEq(uint(orderStatus), uint(Marketplace.OrderStatus.Delivered));
    }
    
    function test_ResolveDisputeEmitsEvent() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        _shipItem(orderId);
        
        vm.prank(buyer);
        marketplace.raiseDispute(orderId);
        
        vm.expectEmit(true, true, false, true);
        emit Marketplace.DisputeResolved(orderId, buyer, ITEM_PRICE);
        
        marketplace.resolveDispute(orderId, true);
    }
    
    function test_OnlyAdminCanResolveDispute() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        _shipItem(orderId);
        
        vm.prank(buyer);
        marketplace.raiseDispute(orderId);
        
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.NotAdmin.selector, seller));
        marketplace.resolveDispute(orderId, true);
    }
    
    function test_CanOnlyResolveDisputedOrders() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        _shipItem(orderId);
        
        vm.expectRevert(abi.encodeWithSelector(Marketplace.OrderNotInDispute.selector, orderId));
        marketplace.resolveDispute(orderId, true);
    }
    
    // =================
    // UTILITY FUNCTIONS
    // =================
    
    function test_GetOrderCountWithAssertChecks() public {
        assertEq(marketplace.getOrderCount(), 0);
        
        uint256 itemId = _listItem();
        _purchaseItem(itemId);
        
        assertEq(marketplace.getOrderCount(), 1);
    }
    
    function test_GetItemReturnsCorrectDetails() public {
        uint256 itemId = _listItem();
        
        Marketplace.Item memory item = marketplace.getItem(itemId);
        assertEq(item.name, ITEM_NAME);
        assertEq(item.description, ITEM_DESCRIPTION);
        assertEq(item.price, ITEM_PRICE);
    }
    
    function test_GetItemRevertsForInvalidId() public {
        vm.expectRevert("Invalid item ID");
        marketplace.getItem(999);
    }
    
    // ============================
    // FALLBACK AND RECEIVE FUNCTIONS
    // ============================
    
    function test_ReceiveHandlesDirectETHTransfers() public {
        vm.expectEmit(true, false, false, true);
        emit Marketplace.UnexpectedPayment(buyer, 1 ether);
        
        vm.prank(buyer);
        (bool success,) = address(marketplace).call{value: 1 ether}("");
        assertTrue(success);
    }
    
    function test_FallbackRevertsOnUnknownFunctionCalls() public {
    vm.prank(buyer);
    (bool success,) = address(marketplace).call{value: 0}(abi.encodeWithSelector(0x12345678));
    assertFalse(success);
    }
    
    // ====================
    // EDGE CASES AND SECURITY
    // ====================
    
    function test_MultipleItemsFromSameSeller() public {
        vm.startPrank(seller);
        marketplace.listItem("Item 1", "First item", 1 ether);
        marketplace.listItem("Item 2", "Second item", 2 ether);
        vm.stopPrank();
        
        assertEq(marketplace.itemCounter(), 2);
        
        uint256 userItem1 = marketplace.userItems(seller, 0);
        uint256 userItem2 = marketplace.userItems(seller, 1);
        
        assertEq(userItem1, 1);
        assertEq(userItem2, 2);
    }
    
    function test_ContractHoldsEscrowFundsCorrectly() public {
        uint256 itemId = _listItem();
        uint256 initialBalance = address(marketplace).balance;
        
        _purchaseItem(itemId);
        
        uint256 finalBalance = address(marketplace).balance;
        assertEq(finalBalance - initialBalance, ITEM_PRICE);
    }
    
    function test_OrderStateTransitions() public {
        uint256 itemId = _listItem();
        uint256 orderId = _purchaseItem(itemId);
        
        (
            ,
            ,
            ,
            ,
            Marketplace.OrderStatus orderStatus,
            
        ) = marketplace.orders(orderId);
        assertEq(uint(orderStatus), uint(Marketplace.OrderStatus.Pending));
        
        _shipItem(orderId);
        (
            ,
            ,
            ,
            ,
            Marketplace.OrderStatus orderStatus2,
            
        ) = marketplace.orders(orderId);
        assertEq(uint(orderStatus2), uint(Marketplace.OrderStatus.Shipped));
        
        vm.prank(buyer);
        marketplace.confirmReceipt(orderId);
        (
            ,
            ,
            ,
            ,
            Marketplace.OrderStatus orderStatus3,
            
        ) = marketplace.orders(orderId);
        assertEq(uint(orderStatus3), uint(Marketplace.OrderStatus.Delivered));
    }
}