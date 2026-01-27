// Export middlewares for easier imports
module.exports = {
  auth: require('./authMiddleware'),
  admin: require('./adminMiddleware')
};
