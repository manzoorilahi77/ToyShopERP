import React from 'react';

const Footer = () => {
  return (
    <footer className="bg-gray-900 text-gray-300 py-12 mt-16">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 grid grid-cols-1 md:grid-cols-4 gap-8">
        <div>
          <h3 className="text-white text-xl font-bold mb-4">ToyShop</h3>
          <p className="text-sm">Premium toys for all ages. Discover joy, creativity, and learning with every play.</p>
        </div>
        <div>
          <h4 className="text-white font-semibold mb-4">Shop</h4>
          <ul className="space-y-2 text-sm">
            <li><a href="/products" className="hover:text-white">All Products</a></li>
            <li><a href="#" className="hover:text-white">New Arrivals</a></li>
            <li><a href="#" className="hover:text-white">Best Sellers</a></li>
            <li><a href="#" className="hover:text-white">Offers</a></li>
          </ul>
        </div>
        <div>
          <h4 className="text-white font-semibold mb-4">Customer Service</h4>
          <ul className="space-y-2 text-sm">
            <li><a href="#" className="hover:text-white">Contact Us</a></li>
            <li><a href="#" className="hover:text-white">Shipping Policy</a></li>
            <li><a href="#" className="hover:text-white">Returns & Exchanges</a></li>
            <li><a href="#" className="hover:text-white">FAQ</a></li>
          </ul>
        </div>
        <div>
          <h4 className="text-white font-semibold mb-4">Newsletter</h4>
          <p className="text-sm mb-4">Subscribe to receive updates, access to exclusive deals, and more.</p>
          <div className="flex">
            <input type="email" placeholder="Enter your email" className="bg-gray-800 text-white px-4 py-2 rounded-l-md focus:outline-none w-full" />
            <button className="bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded-r-md text-white">Subscribe</button>
          </div>
        </div>
      </div>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-12 pt-8 border-t border-gray-800 text-sm text-center">
        <p>&copy; {new Date().getFullYear()} ToyShop. All rights reserved.</p>
      </div>
    </footer>
  );
};

export default Footer;
