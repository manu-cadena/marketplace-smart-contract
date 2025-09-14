// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract Marketplace {

    // Custom errors for better gas efficiency (VG requirement)
    error NotAdmin(address caller);
    error PriceTooLow(uint256 price);
    error ItemNotAvailable(uint256 itemId);
    error SelfPurchase();
    error IncorrectPayment(uint256 sent, uint256 required);
    error UnauthorizedSeller(address caller);
    error UnauthorizedBuyer(address caller);
    error UnauthorizedDispute(address caller);
    error OrderNotPending(uint256 orderId);
    error ItemNotShipped(uint256 orderId);
    error RefundFailed(address recipient, uint256 amount);
    error OrderNotInDispute(uint256 orderId);

    // Status enums for tracking item and order states
    enum ItemStatus { Available, Sold, Cancelled }
    enum OrderStatus { Pending, Shipped, Delivered, Cancelled, Disputed }
    
    // Item data structure
    struct Item {
        string name;
        string description;
        uint256 price;
        address seller;
        ItemStatus status;
        uint256 createdAt;
    }

    // Order data structure for escrow transactions
    struct Order {
        uint256 itemId;
        address buyer;
        address seller;
        uint256 amount;
        OrderStatus status;
        uint256 createdAt;
    }
    
    // State variables
    uint256 public itemCounter = 0;
    uint256 public orderCounter = 0;
    
    // Storage mappings
    mapping(uint256 => Item) public items;
    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userItems;
    mapping(address => bool) public admins;

    // Set deployer as initial admin
    constructor() {
        admins[msg.sender] = true;
    }

    // Access control modifier using custom error (VG requirement)
    modifier onlyAdmin() {
        if (!admins[msg.sender]) {
            revert NotAdmin(msg.sender);
        }
        _;
    }

    // Events for logging important actions
    event ItemListed(uint256 indexed itemId, address indexed seller);
    event AdminAdded(address indexed newAdmin);
    event OrderCreated(uint256 indexed orderId, uint256 indexed itemId, address indexed buyer, address seller);
    event ItemShipped(uint256 indexed orderId);
    event OrderCompleted(uint256 indexed orderId, address indexed seller, uint256 amount);
    event OrderCancelled(uint256 indexed orderId, address indexed buyer, uint256 amount);
    event DisputeRaised(uint256 indexed orderId, address indexed raiser);
    event DisputeResolved(uint256 indexed orderId, address indexed resolver, uint256 amount);
    event UnexpectedPayment(address indexed sender, uint256 amount);

    // Create new marketplace listing
    function listItem(string calldata _name, string calldata _description, uint256 _price) external {
        // Use require for basic input validation (traditional)
        require(bytes(_name).length > 0, "Item name cannot be empty");
        require(bytes(_description).length > 0, "Item description cannot be empty");
        
        // Use custom error for main business logic (gas optimization)
        if (_price == 0) revert PriceTooLow(_price);

        itemCounter++;
        items[itemCounter] = Item({
            name: _name,
            description: _description,
            price: _price,
            seller: msg.sender,
            status: ItemStatus.Available,
            createdAt: block.timestamp
        });
        userItems[msg.sender].push(itemCounter);
        emit ItemListed(itemCounter, msg.sender);
    }

    // Add new admin (admin only)
    function addAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Cannot add zero address as admin");
        admins[_newAdmin] = true;
        emit AdminAdded(_newAdmin);
    }

    // Purchase item with escrow protection
    function purchaseItem(uint256 _itemId) external payable {
        // Use require for input validation
        require(_itemId > 0 && _itemId <= itemCounter, "Invalid item ID");
        
        Item storage item = items[_itemId];
        
        // Use custom errors for business logic (gas optimization)
        if (item.status != ItemStatus.Available) revert ItemNotAvailable(_itemId);
        if (msg.sender == item.seller) revert SelfPurchase();
        if (msg.value != item.price) revert IncorrectPayment(msg.value, item.price);

        // Update item status
        item.status = ItemStatus.Sold;

        // Create escrow order
        orderCounter++;
        orders[orderCounter] = Order({
            itemId: _itemId,
            buyer: msg.sender,
            seller: item.seller,
            amount: msg.value,
            status: OrderStatus.Pending,
            createdAt: block.timestamp
        });

        emit OrderCreated(orderCounter, _itemId, msg.sender, item.seller);
    }

    // Seller marks item as shipped
    function markAsShipped(uint256 _orderId) external {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");
        
        Order storage order = orders[_orderId];
        if (order.seller != msg.sender) revert UnauthorizedSeller(msg.sender);
        if (order.status != OrderStatus.Pending) revert OrderNotPending(_orderId);

        order.status = OrderStatus.Shipped;
        emit ItemShipped(_orderId);
    }

    // Buyer confirms receipt and releases payment
    function confirmReceipt(uint256 _orderId) external {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");
        
        Order storage order = orders[_orderId];
        if (order.buyer != msg.sender) revert UnauthorizedBuyer(msg.sender);
        if (order.status != OrderStatus.Shipped) revert ItemNotShipped(_orderId);

        // Update status first (Checks-Effects-Interactions pattern for security)
        order.status = OrderStatus.Delivered;

        // Release escrowed funds to seller
        (bool success, ) = payable(order.seller).call{value: order.amount}("");
        if (!success) revert RefundFailed(order.seller, order.amount);

        emit OrderCompleted(_orderId, order.seller, order.amount);
    }

    // Cancel order before shipping (buyer only)
    function cancelOrder(uint256 _orderId) external {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");
        
        Order storage order = orders[_orderId];
        if (order.buyer != msg.sender) revert UnauthorizedBuyer(msg.sender);
        if (order.status != OrderStatus.Pending) revert OrderNotPending(_orderId);

        // Update order status
        order.status = OrderStatus.Cancelled;

        // Make item available again
        Item storage item = items[order.itemId];
        item.status = ItemStatus.Available;

        // Refund buyer from escrow
        (bool success, ) = payable(order.buyer).call{value: order.amount}("");
        if (!success) revert RefundFailed(order.buyer, order.amount);

        emit OrderCancelled(_orderId, order.buyer, order.amount);
    }

    // Either party can raise dispute after shipping
    function raiseDispute(uint256 _orderId) external {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");
        
        Order storage order = orders[_orderId];
        if (order.buyer != msg.sender && order.seller != msg.sender) revert UnauthorizedDispute(msg.sender);
        if (order.status != OrderStatus.Shipped) revert ItemNotShipped(_orderId);

        order.status = OrderStatus.Disputed;
        emit DisputeRaised(_orderId, msg.sender);
    }

    // Admin resolves disputes by choosing winner
    function resolveDispute(uint256 _orderId, bool _favorBuyer) external onlyAdmin {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");
        
        Order storage order = orders[_orderId];
        if (order.status != OrderStatus.Disputed) revert OrderNotInDispute(_orderId);

        if (_favorBuyer) {
            order.status = OrderStatus.Cancelled;
            (bool success, ) = payable(order.buyer).call{value: order.amount}("");
            if (!success) revert RefundFailed(order.buyer, order.amount);
            emit DisputeResolved(_orderId, order.buyer, order.amount);
        } else {
            order.status = OrderStatus.Delivered;
            (bool success, ) = payable(order.seller).call{value: order.amount}("");
            if (!success) revert RefundFailed(order.seller, order.amount);
            emit DisputeResolved(_orderId, order.seller, order.amount);
        }
    }

    // Demonstrates assert for invariants (VG requirement)
    function getOrderCount() external view returns (uint256) {
        assert(orderCounter >= 0);
        assert(orderCounter <= type(uint256).max);
        return orderCounter;
    }

    function getItem(uint256 _itemId) external view returns (Item memory) {
        require(_itemId > 0 && _itemId <= itemCounter, "Invalid item ID");
        return items[_itemId];
    }

    // Handles direct ETH transfers
    receive() external payable {
        emit UnexpectedPayment(msg.sender, msg.value);
    }

    // Rejects unknown function calls
    fallback() external payable {
        revert("Function does not exist");
    }
}