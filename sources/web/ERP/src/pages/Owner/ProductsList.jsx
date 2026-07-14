import React, { useState } from 'react';
import { Plus, Edit, Trash2 } from 'lucide-react';
import DataTable from '../../components/ui/DataTable';
import Modal from '../../components/ui/Modal';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import toast from 'react-hot-toast';

import { getCatalog, getCategories, createProduct, updateProduct, deleteProduct } from '../../services/productService';

const productSchema = z.object({
  name: z.string().min(2, 'Name is required'),
  sku: z.string().min(2, 'SKU is required'),
  categoryId: z.number().min(1, 'Category is required'),
  price: z.number().min(0, 'Price must be positive'),
  stock: z.number()
});


export default function ProductsList() {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingProduct, setEditingProduct] = useState(null);
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);

  React.useEffect(() => {
    loadData();
  }, []);

  const loadData = React.useCallback(async () => {
    try {
      const [prodRes, catRes] = await Promise.all([getCatalog(), getCategories()]);
      setProducts(prodRes.data || []);
      setCategories(catRes.data || []);
    } catch (error) {
      toast.error('Failed to load products');
    } finally {
      setLoading(false);
    }
  }, []);

  const { register, handleSubmit, reset, formState: { errors } } = useForm({
    resolver: zodResolver(productSchema)
  });

  const onSubmit = async (data) => {
    try {
      if (editingProduct) {
        const updatedStock = editingProduct.stock + (data.stock || 0);
        await updateProduct(editingProduct.id, { ...data, stock: updatedStock });
        toast.success('Product updated successfully!');
      } else {
        await createProduct({ ...data, image: 'https://images.unsplash.com/photo-1596461404969-9ae70f2830c1?auto=format&fit=crop&w=300&q=80' });
        toast.success('Product added successfully!');
      }
      setIsModalOpen(false);
      setEditingProduct(null);
      reset();
      loadData();
    } catch (error) {
      toast.error(error.response?.data?.message || 'Failed to save product');
    }
  };

  const handleEdit = React.useCallback((product) => {
    setEditingProduct(product);
    reset({
      name: product.name,
      sku: product.sku,
      categoryId: product.categoryId,
      price: product.price,
      stock: 0,
    });
    setIsModalOpen(true);
  }, [reset]);

  const handleDelete = React.useCallback(async (id) => {
    if (window.confirm('Are you sure you want to delete this product?')) {
      try {
        await deleteProduct(id);
        toast.success('Product deleted successfully');
        loadData();
      } catch (error) {
        toast.error('Failed to delete product');
      }
    }
  }, [loadData]);

  const filters = React.useMemo(() => [
    {
      id: 'category',
      label: 'Category',
      options: categories.map(c => ({ value: c.name, label: c.name }))
    },
    {
      id: 'status',
      label: 'Status',
      options: [
        { value: 'In Stock', label: 'In Stock' },
        { value: 'Low Stock', label: 'Low Stock' },
        { value: 'Out of Stock', label: 'Out of Stock' }
      ]
    }
  ], [categories]);

  const columns = React.useMemo(
    () => [
      {
        accessorKey: 'sku',
        header: 'SKU',
        cell: info => <span className="font-mono text-sm">TY-{info.row.original.id.toString().padStart(3, '0')}</span>,
      },
      {
        accessorKey: 'name',
        header: 'Product Name',
        cell: info => <span className="font-medium text-slate-900">{info.getValue()}</span>,
      },
      {
        id: 'category',
        accessorFn: row => row.category?.name || 'N/A',
        header: 'Category',
        cell: info => <span>{info.getValue()}</span>,
      },
      {
        accessorKey: 'price',
        header: 'Price',
        cell: info => `$${Number(info.getValue() || 0).toFixed(2)}`,
      },
      {
        accessorKey: 'stock',
        header: 'Stock',
      },
      {
        id: 'status',
        accessorFn: row => {
          if (row.stock === 0) return 'Out of Stock';
          if (row.stock < 10) return 'Low Stock';
          return 'In Stock';
        },
        header: 'Status',
        cell: info => {
          const status = info.getValue();
          let color = 'bg-green-100 text-green-800';
          
          if (status === 'Out of Stock') {
            color = 'bg-red-100 text-red-800';
          } else if (status === 'Low Stock') {
            color = 'bg-orange-100 text-orange-800';
          }
          
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
        cell: (info) => (
          <div className="flex gap-2">
            <button 
              onClick={() => handleEdit(info.row.original)}
              className="p-1.5 text-blue-600 hover:bg-blue-50 rounded-md transition-colors"
            >
              <Edit className="w-4 h-4" />
            </button>
            <button 
              onClick={() => handleDelete(info.row.original.id)}
              className="p-1.5 text-red-600 hover:bg-red-50 rounded-md transition-colors"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          </div>
        )
      }
    ],
    [handleEdit, handleDelete]
  );

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-2xl font-bold text-slate-800 font-heading">Products Catalog</h1>
          <p className="text-slate-500 mt-1 text-sm">Manage your inventory, prices, and stock levels.</p>
        </div>
        <button 
          onClick={() => {
            setEditingProduct(null);
            reset({
              name: '',
              sku: '',
              categoryId: '',
              price: '',
              stock: ''
            });
            setIsModalOpen(true);
          }}
          className="btn-primary"
        >
          <Plus className="w-4 h-4 mr-2" />
          Add Product
        </button>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
        </div>
      ) : (
        <DataTable 
          data={products} 
          columns={columns} 
          filters={filters}
        />
      )}

      <Modal
        isOpen={isModalOpen}
        onClose={() => {
          setIsModalOpen(false);
          setEditingProduct(null);
          reset();
        }}
        title={editingProduct ? "Edit Product" : "Add New Product"}
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
              <select {...register('categoryId', { valueAsNumber: true })} className="input-field">
                <option value="">Select Category</option>
                {categories.map(cat => (
                  <option key={cat.id} value={cat.id}>{cat.name}</option>
                ))}
              </select>
              {errors.categoryId && <p className="mt-1 text-xs text-red-500">{errors.categoryId.message}</p>}
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
                <label className="block text-sm font-medium text-slate-700 mb-1">
                  {editingProduct ? 'Add/Reduce Stock' : 'Initial Stock'}
                </label>
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
              onClick={() => {
                setIsModalOpen(false);
                setEditingProduct(null);
                reset();
              }}
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
