import React, { useState } from 'react';
import {
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  useReactTable,
} from '@tanstack/react-table';
import { ChevronDown, ChevronUp, ChevronLeft, ChevronRight, Search, SlidersHorizontal } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

export default function DataTable({ data, columns, title, filters }) {
  const [sorting, setSorting] = useState([]);
  const [globalFilter, setGlobalFilter] = useState('');
  const [columnFilters, setColumnFilters] = useState([]);
  const [isFilterOpen, setIsFilterOpen] = useState(false);

  const table = useReactTable({
    data,
    columns,
    state: {
      sorting,
      globalFilter,
      columnFilters,
    },
    onSortingChange: setSorting,
    onGlobalFilterChange: setGlobalFilter,
    onColumnFiltersChange: setColumnFilters,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
  });

  return (
    <div className="card flex flex-col overflow-hidden">
      {/* Toolbar */}
      <div className="p-5 border-b border-slate-200 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        {title && <h3 className="text-lg font-semibold text-slate-800">{title}</h3>}
        
        <div className="flex items-center gap-3 w-full sm:w-auto">
          <div className="relative flex-1 sm:w-64">
            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              value={globalFilter ?? ''}
              onChange={e => setGlobalFilter(e.target.value)}
              className="input-field pl-9 h-9"
              placeholder="Search all columns..."
            />
          </div>
          <div className="relative">
            <button 
              onClick={() => setIsFilterOpen(!isFilterOpen)}
              className="btn-secondary h-9 px-3"
            >
              <SlidersHorizontal className="w-4 h-4 mr-2" />
              Filter
            </button>
            {isFilterOpen && filters && filters.length > 0 && (
              <div className="absolute right-0 mt-2 w-64 bg-white border border-slate-200 rounded-lg shadow-xl z-50 p-4">
                <h4 className="text-sm font-semibold text-slate-800 mb-3">Filters</h4>
                <div className="space-y-4">
                  {filters.map(filter => {
                    const activeFilter = columnFilters.find(f => f.id === filter.id);
                    return (
                      <div key={filter.id}>
                        <label className="block text-xs font-medium text-slate-700 mb-1">{filter.label}</label>
                        <select 
                          className="w-full text-sm border-slate-300 rounded-md shadow-sm focus:border-primary-500 focus:ring-primary-500"
                          value={activeFilter?.value ?? ''}
                          onChange={e => {
                            const val = e.target.value;
                            setColumnFilters(prev => {
                              const newFilters = prev.filter(f => f.id !== filter.id);
                              if (val) {
                                newFilters.push({ id: filter.id, value: val });
                              }
                              return newFilters;
                            });
                          }}
                        >
                          <option value="">All {filter.label}</option>
                          {filter.options.map(opt => (
                            <option key={opt.value} value={opt.value}>{opt.label}</option>
                          ))}
                        </select>
                      </div>
                    );
                  })}
                </div>
                <div className="mt-4 pt-4 border-t border-slate-100 flex justify-end">
                  <button 
                    onClick={() => {
                      setColumnFilters([]);
                      setIsFilterOpen(false);
                    }}
                    className="text-xs text-slate-500 hover:text-slate-700 font-medium"
                  >
                    Clear All
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Table Area */}
      <div className="overflow-x-auto w-full">
        <table className="w-full text-sm text-left">
          <thead className="text-xs text-slate-500 uppercase bg-slate-50 border-b border-slate-200">
            {table.getHeaderGroups().map(headerGroup => (
              <tr key={headerGroup.id}>
                {headerGroup.headers.map(header => (
                  <th 
                    key={header.id} 
                    className="px-6 py-4 font-semibold whitespace-nowrap cursor-pointer hover:bg-slate-100 transition-colors"
                    onClick={header.column.getToggleSortingHandler()}
                  >
                    <div className="flex items-center gap-2">
                      {flexRender(
                        header.column.columnDef.header,
                        header.getContext()
                      )}
                      {{
                        asc: <ChevronUp className="w-4 h-4" />,
                        desc: <ChevronDown className="w-4 h-4" />,
                      }[header.column.getIsSorted()] ?? null}
                    </div>
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody className="divide-y divide-slate-100 bg-white">
            <AnimatePresence>
              {table.getRowModel().rows.map(row => (
                <motion.tr 
                  key={row.id}
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  className="hover:bg-slate-50/80 transition-colors"
                >
                  {row.getVisibleCells().map(cell => (
                    <td key={cell.id} className="px-6 py-4 text-slate-600">
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  ))}
                </motion.tr>
              ))}
            </AnimatePresence>
            {table.getRowModel().rows.length === 0 && (
              <tr>
                <td colSpan={columns.length} className="px-6 py-8 text-center text-slate-500">
                  No data found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      <div className="p-4 border-t border-slate-200 flex items-center justify-between bg-slate-50/50">
        <div className="text-sm text-slate-500">
          Showing {table.getRowModel().rows.length > 0 ? table.getState().pagination.pageIndex * table.getState().pagination.pageSize + 1 : 0} to {Math.min((table.getState().pagination.pageIndex + 1) * table.getState().pagination.pageSize, table.getFilteredRowModel().rows.length)} of {table.getFilteredRowModel().rows.length} entries
        </div>
        
        <div className="flex items-center gap-2">
          <button
            onClick={() => table.previousPage()}
            disabled={!table.getCanPreviousPage()}
            className="p-1 rounded-md border border-slate-300 bg-white text-slate-500 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            <ChevronLeft className="w-5 h-5" />
          </button>
          <button
            onClick={() => table.nextPage()}
            disabled={!table.getCanNextPage()}
            className="p-1 rounded-md border border-slate-300 bg-white text-slate-500 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            <ChevronRight className="w-5 h-5" />
          </button>
        </div>
      </div>
    </div>
  );
}
