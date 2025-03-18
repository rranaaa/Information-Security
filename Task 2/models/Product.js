const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Product = sequelize.define('Product', {
    pid: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    pname: { type: DataTypes.STRING, allowNull: false },
    description: { type: DataTypes.STRING },
    price: { type: DataTypes.FLOAT, allowNull: false },
    stock: { type: DataTypes.INTEGER, allowNull: false }
}, {
    timestamps: false  // Disable createdAt and updatedAt
});

module.exports = Product;
