// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract Marketplace {
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

    // Access control modifier
    modifier onlyAdmin() {
        require(admins[msg.sender], "Not an admin");
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

    // Create new marketplace listing
    function listItem(string calldata _name, string calldata _description, uint256 _price) external {
        require(_price > 0, "Price must be greater than zero");
        
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
        admins[_newAdmin] = true;
        emit AdminAdded(_newAdmin);
    }

    // Purchase item with escrow protection
    function purchaseItem(uint256 _itemId) external payable {
        Item storage item = items[_itemId];
        require(item.status == ItemStatus.Available, "Item not available");
        require(msg.sender != item.seller, "Seller cannot buy their own item");
        require(msg.value == item.price, "Incorrect payment amount");

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
        Order storage order = orders[_orderId];
        require(order.seller == msg.sender, "Only seller can mark as shipped");
        require(order.status == OrderStatus.Pending, "Order not in pending state");

        order.status = OrderStatus.Shipped;
        emit ItemShipped(_orderId);
    }

    // Buyer confirms receipt and releases payment
    function confirmReceipt(uint256 _orderId) external {
        Order storage order = orders[_orderId];
        require(order.buyer == msg.sender, "Only buyer can confirm receipt");
        require(order.status == OrderStatus.Shipped, "Item not shipped yet");

        // Update status first (Checks-Effects-Interactions pattern for security)
        order.status = OrderStatus.Delivered;

        // Release escrowed funds to seller
        (bool success, ) = payable(order.seller).call{value: order.amount}("");
        require(success, "Transfer to seller failed");

        emit OrderCompleted(_orderId, order.seller, order.amount);
    }

    // Cancel order before shipping (buyer only)
    function cancelOrder(uint256 _orderId) external {
        Order storage order = orders[_orderId];
        require(order.buyer == msg.sender, "Only buyer can cancel order");
        require(order.status == OrderStatus.Pending, "Can only cancel pending orders");

        // Update order status
        order.status = OrderStatus.Cancelled;

        // Make item available again
        Item storage item = items[order.itemId];
        item.status = ItemStatus.Available;

        // Refund buyer from escrow
        (bool success, ) = payable(order.buyer).call{value: order.amount}("");
        require(success, "Refund to buyer failed");

        emit OrderCancelled(_orderId, order.buyer, order.amount);
    }

    // Raise dispute after shipping
    function raiseDispute(uint256 _orderId) external {
        Order storage order = orders[_orderId];
        require(order.buyer == msg.sender || order.seller == msg.sender, "Only buyer or seller can raise dispute");
        require(order.status == OrderStatus.Shipped, "Can only dispute shipped orders");

        order.status = OrderStatus.Disputed;
        emit DisputeRaised(_orderId, msg.sender);
    }

    // Admin resolves disputes
    function resolveDispute(uint256 _orderId, bool _favorBuyer) external onlyAdmin {
        Order storage order = orders[_orderId];
        require(order.status == OrderStatus.Disputed, "Order not in dispute");
        
        if (_favorBuyer) {
            // Refund buyer
            order.status = OrderStatus.Cancelled;
            (bool success, ) = payable(order.buyer).call{value: order.amount}("");
            require(success, "Refund failed");
            emit DisputeResolved(_orderId, order.buyer, order.amount);
        } else {
            // Pay seller
            order.status = OrderStatus.Delivered;
            (bool success, ) = payable(order.seller).call{value: order.amount}("");
            require(success, "Payment failed");
            emit DisputeResolved(_orderId, order.seller, order.amount);
        }
    }
}