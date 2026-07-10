// Mock data for the ToyShop Staff Application

export const CATEGORIES = [
  { id: 'cat1', name: 'Action Figures', icon: 'zap', color: 'bg-red-500' },
  { id: 'cat2', name: 'Board Games', icon: 'dice-5', color: 'bg-blue-500' },
  { id: 'cat3', name: 'Plushies', icon: 'heart', color: 'bg-pink-500' },
  { id: 'cat4', name: 'Puzzles', icon: 'puzzle', color: 'bg-green-500' },
  { id: 'cat5', name: 'Vehicles', icon: 'car', color: 'bg-yellow-500' },
];

export const CATALOG = [
  { id: 'p1', name: 'Superhero Action Figure', categoryId: 'cat1', price: 599, stock: 15, isFavorite: true, image: 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?auto=format&fit=crop&w=300&q=80' },
  { id: 'p2', name: 'Monopoly Classic', categoryId: 'cat2', price: 999, stock: 5, isFavorite: true, image: 'https://images.unsplash.com/photo-1611891487122-207578368580?auto=format&fit=crop&w=300&q=80' },
  { id: 'p3', name: 'Teddy Bear', categoryId: 'cat3', price: 450, stock: 20, isFavorite: false, image: 'https://images.unsplash.com/photo-1559454403-b8fb88521f11?auto=format&fit=crop&w=300&q=80' },
  { id: 'p4', name: '1000 Piece Landscape Puzzle', categoryId: 'cat4', price: 750, stock: 8, isFavorite: false, image: 'https://images.unsplash.com/photo-1601296200639-89349ce76a48?auto=format&fit=crop&w=300&q=80' },
  { id: 'p5', name: 'Die-cast Sports Car', categoryId: 'cat5', price: 299, stock: 30, isFavorite: true, image: 'https://images.unsplash.com/photo-1594787318286-3d835c1d207f?auto=format&fit=crop&w=300&q=80' },
  { id: 'p6', name: 'Villain Action Figure', categoryId: 'cat1', price: 549, stock: 12, isFavorite: false, image: 'https://images.unsplash.com/photo-1533513745265-d41a773de90c?auto=format&fit=crop&w=300&q=80' },
  { id: 'p7', name: 'Scrabble', categoryId: 'cat2', price: 899, stock: 0, isFavorite: false, image: 'https://images.unsplash.com/photo-1585644782012-78d1fb52c803?auto=format&fit=crop&w=300&q=80' },
  { id: 'p8', name: 'RC Monster Truck', categoryId: 'cat5', price: 1499, stock: 3, isFavorite: true, image: 'https://images.unsplash.com/photo-1594788094620-4579ad50c7fe?auto=format&fit=crop&w=300&q=80' },
];

export const STAFF_STATS = {
  salesToday: 14,
  revenueToday: 12450,
  trendPct: 8.5,
  lifetimeUnits: 1432,
  lifetimeSales: 1250000,
  monthPoints: 450,
  rankLabel: 'Top 5%'
};

export const LEADERBOARD = [
  { id: 1, name: 'Ravi K.', initials: 'RK', color: 'bg-blue-600', rank: 1, points: 520, isMe: true },
  { id: 2, name: 'Anbu S.', initials: 'AS', color: 'bg-green-600', rank: 2, points: 490, isMe: false },
  { id: 3, name: 'Meena R.', initials: 'MR', color: 'bg-pink-600', rank: 3, points: 410, isMe: false },
];

export const SALES_HISTORY = [
  { id: 'INV-1001', time: '10:45 AM', items: 3, total: 1897, status: 'synced' },
  { id: 'INV-1002', time: '11:15 AM', items: 1, total: 999, status: 'synced' },
  { id: 'INV-1003', time: '12:30 PM', items: 5, total: 3245, status: 'failed' },
  { id: 'INV-1004', time: '02:05 PM', items: 2, total: 1048, status: 'synced' },
];

export const BADGES = [
  { id: 1, title: 'First Sale', icon: 'award', earned: true, criteria: 'Complete your first sale' },
  { id: 2, title: 'Speed Demon', icon: 'zap', earned: true, criteria: 'Checkout under 30 seconds' },
  { id: 3, title: 'Top Seller', icon: 'star', earned: false, criteria: 'Sell 100 items in a week' },
  { id: 4, title: 'Big Ticket', icon: 'banknote', earned: false, criteria: 'Sale over ₹5000' },
];
