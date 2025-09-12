// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract Marketplace {
    // Enums for status tracking
    enum ItemStatus { Available, Sold, Cancelled }
    enum OrderStatus { Pending, Shipped, Delivered, Cancelled, Disputed }
    
    // Structs - Define before using in mappings
    struct Item {
        string name;
        string description;
        uint256 price;        // Price in wei (smallest ETH unit)
        address seller;       // Who's selling it
        ItemStatus status;    // Available, Sold, Cancelled
        uint256 createdAt;    // When it was listed
    }

    struct Order {
        uint256 itemId;       // Which item is being bought
        address buyer;        // Who's buying
        address seller;       // Who's selling
        uint256 amount;       // How much was paid
        OrderStatus status;   // Pending, Shipped, etc.
        uint256 createdAt;    // When order was created
    }
    
    // State variables
    uint256 public itemCounter = 0;
    uint256 public orderCounter = 0;
    
    // Mappings - Our "database"
    mapping(uint256 => Item) public items;           // itemId → Item details
    mapping(uint256 => Order) public orders;        // orderId → Order details
    mapping(address => uint256[]) public userItems; // user → array of their item IDs
    mapping(address => bool) public admins;         // address → is admin?

    // Constructor - Set the deployer as an admin
    constructor() {
    admins[msg.sender] = true;
    }

    modifier onlyAdmin() {
    require(admins[msg.sender], "Not an admin");
    _;
    }

    // Events
    event ItemListed(uint256 indexed itemId, address indexed seller);
    event AdminAdded(address indexed newAdmin);

    // Function to list an item for sale
    function listItem(string memory _name, string calldata _description, uint256 _price) external {
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

    function addAdmin(address _newAdmin) external onlyAdmin {
        admins[_newAdmin] = true;
        emit AdminAdded(_newAdmin);
    }
}