const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const dotenv = require('dotenv');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const sequelize = require('./config/database'); // Import Sequelize instance
const User = require('./models/User'); // Import User model
const Product = require('./models/Product'); // Import Product model

dotenv.config();
const app = express();

app.use(bodyParser.json());
app.use(cors());

// Sync Database with Sequelize (Create tables if they don't exist)
sequelize.sync()
    .then(() => console.log('Database synchronized with Sequelize'))
    .catch(err => console.error('Error syncing database:', err));

// Middleware for authentication
const authenticateToken = (req, res, next) => {
    const token = req.header('Authorization');
    if (!token) return res.status(401).json({ message: 'Access denied' });

    jwt.verify(token.split(' ')[1], process.env.JWT_SECRET, (err, user) => {
        if (err) return res.status(403).json({ message: 'Invalid token' });
        req.user = user;
        next();
    });
};

app.post('/signup', async (req, res) => {
    const { name, username, password } = req.body;
    try {
        const hashedPassword = await bcrypt.hash(password, 10);
        const user = await User.create({ name, username, password: hashedPassword });
        res.status(201).json({ message: 'User registered', user });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/login', async (req, res) => {
    const { username, password } = req.body;
    try {
        const user = await User.findOne({ where: { username } });
        if (!user) return res.status(400).json({ message: 'Invalid credentials' });

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) return res.status(400).json({ message: 'Invalid credentials' });

        const token = jwt.sign({ id: user.id, username: user.username }, process.env.JWT_SECRET, { expiresIn: '10m' });
        res.json({ token });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/users/:id', authenticateToken, async (req, res) => {
    const { name, username } = req.body;
    try {
        const user = await User.findByPk(req.params.id);
        if (!user) return res.status(404).json({ message: 'User not found' });

        await user.update({ name, username });
        res.json({ message: 'User updated', user });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});


app.post('/products', authenticateToken, async (req, res) => {
    try {
        const product = await Product.create(req.body);
        res.status(201).json({ message: 'Product added', product });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/products', authenticateToken, async (req, res) => {
    try {
        const products = await Product.findAll();
        res.json(products);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/products/:pid', authenticateToken, async (req, res) => {
    try {
        const product = await Product.findByPk(req.params.pid);
        if (!product) return res.status(404).json({ message: 'Product not found' });
        res.json(product);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/products/:pid', authenticateToken, async (req, res) => {
    try {
        const updated = await Product.update(req.body, { where: { pid: req.params.pid } });
        if (updated[0] === 0) return res.status(404).json({ message: 'Product not found' });
        res.json({ message: 'Product updated' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/products/:pid', authenticateToken, async (req, res) => {
    try {
        const deleted = await Product.destroy({ where: { pid: req.params.pid } });
        if (!deleted) return res.status(404).json({ message: 'Product not found' });
        res.json({ message: 'Product deleted' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});


const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
