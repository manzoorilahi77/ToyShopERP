import React, { useState } from 'react';
import { Plus, Edit, Trash2 } from 'lucide-react';
import DataTable from '../../components/ui/DataTable';
import Modal from '../../components/ui/Modal';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import toast from 'react-hot-toast';

// Mock Data
const productsData = [
  { id: '1', sku: 'TY-001', name: 'Lego City Police Station', category: 'Building Blocks', stock: 45, price: 99.99, status: 'In Stock' },
  { id: '2', sku: 'TY-002', name: 'Barbie Dreamhouse', category: 'Dolls', stock: 12, price: 199.99, status: 'Low Stock' },
  { id: '3', sku: 'TY-003', name: 'Hot Wheels Track Builder', category: 'Vehicles', stock: 0, price: 49.99, status: 'Out of Stock' },
  { id: '4', sku: 'TY-004', name: 'Monopoly Classic', category: 'Board Games', stock: 85, price: 29.99, status: 'In Stock' },
  { id: '5', sku: 'TY-005', name: 'Nerf Elite Blaster', category: 'Action', stock: 34, price: 39.99, status: 'In Stock' },
];

const productSchema = z.object({
  name: z.string().min(2, 'Name is required'),
  sku: z.string().min(2, 'SKU is required'),
  category: z.string().min(2, 'Category is required'),
  price: z.number().min(0, 'Price must be positive'),
  stock: z.number().min(0, 'Stock must be 0 or more')
});

export default function ProductsList() {
  const [isModalOpen, setIsModalOpen] = useState(false);

  const { register, handleSubmit, reset, formState: { errors } } = useForm({
    resolver: zodResolver(productSchema)
  });

  const onSubmit = (data) => {
    console.log(data);
    toast.success('Product added successfully!');
    setIsModalOpen(false);
    reset();
  };

  const columns = React.useMemo(
    () => [
      {
        accessorKey: 'sku',
        header: 'SKU',
        cell: info => <span className="font-mono text-sm">{info.getValue()}</span>,
      },
      {
        accessorKey: 'name',
        header: 'Product Name',
        cell: info => <span className="font-medium text-slate-900">{info.getValue()}</span>,
      },
      {
        accessorKey: 'category',
        header: 'Category',
      },
      {
        accessorKey: 'price',
        header: 'Price',
        cell: info => `$${info.getValue().toFixed(2)}`,
      },
      {
        accessorKey: 'stock',
        header: 'Stock',
      },
      {
        accessorKey: 'status',
        header: 'Status',
        cell: info => {
          const status = info.getValue();
          let color = 'bg-slate-100 text-slate-800';
          if (status === 'In Stock') color = 'bg-green-100 text-green-800';
          else if (status === 'Low Stock') color = 'bg-orange-100 text-orange-800';
          else if (status === 'Out of Stock') color = 'bg-red-100 text-red-800';
          
          return (
            <span className={`px-2.5 py-1 rounded-full text-xs font-medium ${color}`}>
              {status}
            </span>
          );
        },
      },
      {
        id: 'actions',
        header: 'Actions',
        cell: () => (
          <div className="flex gap-2">
            <button className="p-1.5 text-blue-600 hover:bg-blue-50 rounded-md transition-colors">
              <Edit className="w-4 h-4" />
            </button>
            <button className="p-1.5 text-red-600 hover:bg-red-50 rounded-md transition-colors">
              <Trash2 className="w-4 h-4" />
            </button>
          </div>
        )
      }
    ],
    []
  );

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-2xl font-bold text-slate-800 font-heading">Products Catalog</h1>
          <p className="text-slate-500 mt-1 text-sm">Manage your inventory, prices, and stock levels.</p>
        </div>
        <button 
          onClick={() => setIsModalOpen(true)}
          className="btn-primary"
        >
          <Plus className="w-4 h-4 mr-2" />
          Add Product
        </button>
      </div>

      <DataTable 
        data={productsData} 
        columns={columns} 
      />

      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title="Add New Product"
      >
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">Product Name</label>
              <input {...register('name')} className="input-field" placeholder="e.g. Lego City" />
              {errors.name && <p className="mt-1 text-xs text-red-500">{errors.name.message}</p>}
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">SKU</label>
              <input {...register('sku')} className="input-field" placeholder="e.g. TY-100" />
              {errors.sku && <p className="mt-1 text-xs text-red-500">{errors.sku.message}</p>}
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">Category</label>
              <select {...register('category')} className="input-field">
                <option value="">Select Category</option>
                <option value="Building Blocks">Building Blocks</option>
                <option value="Dolls">Dolls</option>
                <option value="Vehicles">Vehicles</option>
                <option value="Board Games">Board Games</option>
                <option value="Action">Action Figures</option>
              </select>
              {errors.category && <p className="mt-1 text-xs text-red-500">{errors.category.message}</p>}
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Price ($)</label>
                <input 
                  type="number" 
                  step="0.01" 
                  {...register('price', { valueAsNumber: true })} 
                  className="input-field" 
                  placeholder="0.00" 
                />
                {errors.price && <p className="mt-1 text-xs text-red-500">{errors.price.message}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Stock</label>
                <input 
                  type="number" 
                  {...register('stock', { valueAsNumber: true })} 
                  className="input-field" 
                  placeholder="0" 
                />
                {errors.stock && <p className="mt-1 text-xs text-red-500">{errors.stock.message}</p>}
              </div>
            </div>
          </div>
          
          <div className="pt-4 border-t border-slate-100 flex justify-end gap-3 mt-6">
            <button 
              type="button" 
              onClick={() => setIsModalOpen(false)}
              className="px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 rounded-lg transition-colors"
            >
              Cancel
            </button>
            <button type="submit" className="btn-primary">
              Save Product
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
