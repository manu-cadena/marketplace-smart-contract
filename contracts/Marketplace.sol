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
}