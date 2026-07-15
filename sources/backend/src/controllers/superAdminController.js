const { Branch, User, Role, Product, Sale, Category } = require('../models');
const { successResponse, errorResponse } = require('../utils/response');

exports.getDashboardStats = async (req, res) => {
  try {
    const totalBranches = await Branch.count({ where: { isActive: true } });
    const totalUsers = await User.count();
    
    // MRR is sum of sales
    const sales = await Sale.findAll();
    const mrr = sales.reduce((sum, sale) => sum + Number(sale.totalAmount || 0), 0);

    const kpis = [
      { id: 1, title: 'Active Tenants', value: totalBranches.toString(), iconName: 'Store', color: 'text-blue-600', bg: 'bg-blue-100' },
      { id: 2, title: 'Total Users', value: totalUsers.toString(), iconName: 'Users', color: 'text-purple-600', bg: 'bg-purple-100' },
      { id: 3, title: 'System Health', value: '99.9%', iconName: 'Activity', color: 'text-emerald-600', bg: 'bg-emerald-100' },
      { id: 4, title: 'Total Revenue', value: `₹${mrr.toLocaleString()}`, iconName: 'DollarSign', color: 'text-amber-600', bg: 'bg-amber-100' },
    ];

    const recentActivity = [
      { id: 1, text: 'Database backup completed successfully', time: '1 hour ago', type: 'info' },
      { id: 2, text: 'System update v2.4 deployed', time: '5 hours ago', type: 'success' },
    ];

    return successResponse(res, 200, 'Dashboard stats retrieved', { kpis, recentActivity });
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving dashboard stats', [error.message]);
  }
};

exports.getTenants = async (req, res) => {
  try {
    const branches = await Branch.findAll({
      include: [
        { model: User, as: 'users', include: [{ model: Role, as: 'role' }] },
        { model: Sale, as: 'sales' }
      ]
    });

    const tenantsMap = {};

    branches.forEach(branch => {
      // Find the first user with 'Owner' or 'Admin' role, or just pick first user
      const ownerUser = branch.users.find(u => u.role && (u.role.name === 'Owner' || u.role.name === 'Admin')) || branch.users[0];
      const ownerName = ownerUser ? ownerUser.name : 'Unassigned';
      
      const revenue = branch.sales.reduce((sum, s) => sum + Number(s.totalAmount || 0), 0);

      if (!tenantsMap[ownerName]) {
        tenantsMap[ownerName] = {
          id: `T${branch.id.toString().padStart(3, '0')}`,
          name: ownerName === 'Unassigned' ? branch.name : `${ownerName}'s Shop`,
          owner: ownerName,
          plan: 'Pro', // Static for now
          status: branch.isActive ? 'Active' : 'Inactive',
          branches: 0,
          rawRevenue: 0
        };
      }

      tenantsMap[ownerName].branches += 1;
      tenantsMap[ownerName].rawRevenue += revenue;
      // If any branch is active, the tenant is active
      if (branch.isActive) {
        tenantsMap[ownerName].status = 'Active';
      }
    });

    const tenants = Object.values(tenantsMap).map(tenant => ({
      id: tenant.id,
      name: tenant.name,
      owner: tenant.owner,
      plan: tenant.plan,
      status: tenant.status,
      branches: tenant.branches,
      revenue: `₹${tenant.rawRevenue.toLocaleString()}/mo`
    }));

    return successResponse(res, 200, 'Tenants retrieved', tenants);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving tenants', [error.message]);
  }
};

exports.getGlobalStaff = async (req, res) => {
  try {
    const users = await User.findAll({
      include: [
        { model: Role, as: 'role' },
        { model: Branch, as: 'branch' }
      ]
    });

    const staff = users.map(user => ({
      id: `USR-${user.id.toString().padStart(3, '0')}`,
      name: user.name,
      role: user.role ? user.role.name : 'Unknown',
      tenant: user.branch ? user.branch.name : 'System',
      branch: user.branch ? user.branch.location || user.branch.name : 'Global',
      email: user.email,
      status: 'Active'
    }));

    return successResponse(res, 200, 'Global staff retrieved', staff);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving global staff', [error.message]);
  }
};

exports.getGlobalStock = async (req, res) => {
  try {
    const products = await Product.findAll({
      include: [{ model: Category, as: 'category' }]
    });

    const stock = products.map(product => ({
      id: `STK-${product.id.toString().padStart(3, '0')}`,
      name: product.name,
      category: product.category ? product.category.name : 'Uncategorized',
      tenant: 'Global',
      branch: 'All Branches',
      stock: product.stock || 0,
      price: Number(product.price || 0),
      status: product.stock > 20 ? 'In Stock' : (product.stock > 0 ? 'Low Stock' : 'Out of Stock')
    }));

    return successResponse(res, 200, 'Global stock retrieved', stock);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving global stock', [error.message]);
  }
};

exports.getSubscriptions = async (req, res) => {
  try {
    const data = [
      {
        id: 'starter',
        name: 'Starter Plan',
        price: '₹2,999',
        period: '/month',
        iconName: 'Building2',
        color: 'text-blue-600',
        bg: 'bg-blue-50',
        borderColor: 'border-blue-200',
        features: ['Up to 2 Branches', '5 Staff Members', 'Basic Reports', 'Email Support'],
        activeTenants: 45
      },
      {
        id: 'growth',
        name: 'Growth Plan',
        price: '₹5,999',
        period: '/month',
        iconName: 'Zap',
        color: 'text-primary-600',
        bg: 'bg-primary-50',
        borderColor: 'border-primary-200 ring-2 ring-primary-500/20',
        features: ['Up to 5 Branches', 'Unlimited Staff', 'Advanced Analytics', 'Priority 24/7 Support', 'Custom Domain'],
        activeTenants: 82,
        popular: true
      },
      {
        id: 'enterprise',
        name: 'Enterprise',
        price: 'Custom',
        period: '',
        iconName: 'Server',
        color: 'text-slate-700',
        bg: 'bg-slate-100',
        borderColor: 'border-slate-300',
        features: ['Unlimited Branches', 'Dedicated Account Manager', 'Custom Integrations', 'SLA Guarantee', 'On-premise Option'],
        activeTenants: 15
      }
    ];

    return successResponse(res, 200, 'Subscriptions retrieved', data);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving subscriptions', [error.message]);
  }
};

exports.getSystemLogs = async (req, res) => {
  try {
    const logs = [
      { id: 1, time: '2026-07-10 15:28:42', level: 'ERROR', service: 'auth-service', message: 'Failed to connect to redis cache cluster.' },
      { id: 2, time: '2026-07-10 15:28:40', level: 'INFO', service: 'api-gateway', message: 'Incoming request from 192.168.1.45 (Tenant: T004)' },
      { id: 3, time: '2026-07-10 15:27:15', level: 'WARN', service: 'db-writer', message: 'Query execution time exceeded 500ms on table `sales`' },
      { id: 4, time: '2026-07-10 15:25:00', level: 'INFO', service: 'sync-worker', message: 'Successfully synced 45 records for Tenant: T001' },
      { id: 5, time: '2026-07-10 15:24:12', level: 'INFO', service: 'api-gateway', message: 'User logged in: Admin (System)' },
      { id: 6, time: '2026-07-10 15:20:00', level: 'INFO', service: 'system', message: 'Automated health check passed.' },
    ];
    return successResponse(res, 200, 'System logs retrieved', logs);
  } catch (error) {
    return errorResponse(res, 500, 'Error retrieving system logs', [error.message]);
  }
};
