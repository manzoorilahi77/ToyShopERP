# ToyShop ERP - Web Application

Welcome to the frontend repository for the **ToyShop ERP System**. This application is built with **React JS** and serves as the primary interface for managing all operations within the ToyShop ecosystem, from point-of-sale transactions to global administrative tasks.

## 🚀 Features & Modules

The web application is tailored for three distinct roles, ensuring secure and relevant access to operations:

### 1. Super Admin
- **Tenants Management**: Onboard and manage multiple client stores.
- **Global Overview**: Access global stock and staff analytics.
- **Subscriptions & Logs**: Handle billing subscriptions and view critical system activity logs.

### 2. Owner
- **Dashboard**: High-level overview of daily sales, profit, and stock alerts.
- **Branch Management**: Create, edit, and organize multiple store branches.
- **Stock & Products**: Add new inventory, auto-generate SKU IDs, and manage product catalogs.
- **Staff Management**: Assign roles, branches, and manage employee accounts.
- **GST & Reports**: Fully integrated GST compliance (CGST, SGST, IGST) with robust Excel report generation.

### 3. Staff (Cashier/Sales)
- **Point of Sale (New Sale)**: Streamlined checkout process with real-time stock deduction and tax calculations.
- **Sales History**: View previous transactions and generate receipts.
- **Product Catalog**: Quick search functionality to check product availability and pricing.

## 🛠️ Technology Stack

- **Framework**: React.js
- **Styling**: Tailwind CSS (or Custom CSS Modules)
- **Routing**: React Router DOM
- **State Management**: Context API / Redux (depending on configuration)
- **Build Tool**: Vite (or Create React App)

## ⚙️ Getting Started

### Prerequisites
Make sure you have [Node.js](https://nodejs.org/) installed on your machine.

### Installation

1. Navigate to the frontend directory:
   ```bash
   cd sources/web/ERP
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the development server:
   ```bash
   npm run dev
   ```

4. Open your browser and navigate to the local development URL provided in the terminal (usually `http://localhost:5173` or `http://localhost:3000`).

## 📁 Folder Structure

- `/src/pages/` - Contains all the route components, segmented by roles (`/Auth`, `/Owner`, `/Staff`, `/SuperAdmin`).
- `/src/components/` - Reusable UI components used across different pages.
- `/src/assets/` - Static files like images, icons, and stylesheets.

## 📝 Environment Variables
Ensure you have a `.env` file at the root of the `ERP` directory configured with the backend API URL. Example:
```env
VITE_API_BASE_URL=http://localhost:5000/api
```

---
*Developed for the ToyShop ERP Platform.*
