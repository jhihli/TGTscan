"use client"

import { ArrowUpIcon, ArrowDownIcon, PencilIcon, TrashIcon } from '@heroicons/react/24/outline';
import { SO } from "@/interface/IDatatable";
import { getSOs, fetchSOsTotalPage } from '@/app/lib/data';
import { useState, useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { useDeleteMessage } from '@/app/ui/dashboard/table';

const API_URL = process.env.NEXT_PUBLIC_Django_API_URL;

function getAuthHeaders(): HeadersInit {
  return {
    'Content-Type': 'application/json',
    'X-API-Key': process.env.NEXT_PUBLIC_API_KEY || '',
  };
}

function sortData(data: SO[], field: keyof SO, order: 'asc' | 'desc'): SO[] {
  return [...data].sort((a, b) => {
    const aVal = String(a[field] ?? '');
    const bVal = String(b[field] ?? '');
    const cmp = aVal.localeCompare(bVal);
    return order === 'asc' ? cmp : -cmp;
  });
}

export default function SOTable({
  initialSOs,
  query,
  currentPage,
}: {
  initialSOs: SO[];
  query: string;
  currentPage: number;
}) {
  const router = useRouter();
  const [sos, setSOs] = useState<SO[]>(initialSOs);
  const [selectedRows, setSelectedRows] = useState<Set<string>>(new Set());
  const [selectAll, setSelectAll] = useState(false);
  const [sortField, setSortField] = useState<keyof SO>('date');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [deleteConfirm, setDeleteConfirm] = useState<{ open: boolean; id: string | null }>({ open: false, id: null });
  const [bulkDeleteConfirm, setBulkDeleteConfirm] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const { setDeleteMessage } = useDeleteMessage();

  // Refresh data when query / page changes
  useEffect(() => {
    const fetchData = async () => {
      try {
        const fetched = await getSOs(query, currentPage);
        setSOs(fetched);
      } catch (error) {
        console.error('Failed to fetch SOs:', error);
      }
    };
    fetchData();
  }, [query, currentPage]);

  const handleSort = (field: keyof SO) => {
    const newOrder = sortField === field && sortOrder === 'asc' ? 'desc' : 'asc';
    setSortField(field);
    setSortOrder(newOrder);
    setSOs(sortData(sos, field, newOrder));
  };

  const renderSortIcon = (field: keyof SO) => {
    if (sortField !== field) return null;
    return sortOrder === 'asc' ? (
      <ArrowUpIcon className="h-4 w-4 ml-1" />
    ) : (
      <ArrowDownIcon className="h-4 w-4 ml-1" />
    );
  };

  const handleSelectAll = () => {
    if (selectAll) {
      setSelectedRows(new Set());
    } else {
      setSelectedRows(new Set(sos.map((so) => String(so.id))));
    }
    setSelectAll(!selectAll);
  };

  const handleSelectRow = (id: bigint | string) => {
    const stringId = String(id);
    const next = new Set(selectedRows);
    if (next.has(stringId)) {
      next.delete(stringId);
    } else {
      next.add(stringId);
    }
    setSelectedRows(next);
    setSelectAll(false);
  };

  const deleteSO = async (id: string) => {
    setIsDeleting(true);
    try {
      const res = await fetch(`${API_URL}/product/sos/${id}/`, {
        method: 'DELETE',
        headers: getAuthHeaders(),
      });
      if (res.ok || res.status === 204) {
        setSOs((prev) => prev.filter((so) => String(so.id) !== id));
        setDeleteMessage('Delete success');
      } else {
        setDeleteMessage('Delete failed');
      }
    } catch {
      setDeleteMessage('Delete failed');
    } finally {
      setIsDeleting(false);
      setDeleteConfirm({ open: false, id: null });
    }
  };

  const deleteBulk = async () => {
    setIsDeleting(true);
    let successCount = 0;
    for (const id of Array.from(selectedRows)) {
      try {
        const res = await fetch(`${API_URL}/product/sos/${id}/`, {
          method: 'DELETE',
          headers: getAuthHeaders(),
        });
        if (res.ok || res.status === 204) successCount++;
      } catch {
        // continue
      }
    }
    setSOs((prev) => prev.filter((so) => !selectedRows.has(String(so.id))));
    setSelectedRows(new Set());
    setSelectAll(false);
    setDeleteMessage(`Deleted ${successCount} SO(s) successfully`);
    setIsDeleting(false);
    setBulkDeleteConfirm(false);
  };

  return (
    <div className="mt-6 flow-root">
      {/* Single delete confirmation */}
      {deleteConfirm.open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30">
          <div className="bg-white rounded-lg shadow-lg max-w-sm w-full p-6">
            <h3 className="text-base font-semibold text-gray-800 mb-2">Confirm Delete</h3>
            <p className="text-sm text-gray-600 mb-4">Are you sure you want to delete this SO?</p>
            <div className="flex justify-end gap-3">
              <button
                className="px-4 py-2 text-sm rounded-md border border-gray-300 hover:bg-gray-50"
                onClick={() => setDeleteConfirm({ open: false, id: null })}
                disabled={isDeleting}
              >
                Cancel
              </button>
              <button
                className="px-4 py-2 text-sm rounded-md bg-red-600 text-white hover:bg-red-700 disabled:opacity-50"
                onClick={() => deleteConfirm.id && deleteSO(deleteConfirm.id)}
                disabled={isDeleting}
              >
                {isDeleting ? 'Deleting...' : 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Bulk delete confirmation */}
      {bulkDeleteConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30">
          <div className="bg-white rounded-lg shadow-lg max-w-sm w-full p-6">
            <h3 className="text-base font-semibold text-gray-800 mb-2">Confirm Bulk Delete</h3>
            <p className="text-sm text-gray-600 mb-4">
              Delete {selectedRows.size} selected SO(s)? This cannot be undone.
            </p>
            <div className="flex justify-end gap-3">
              <button
                className="px-4 py-2 text-sm rounded-md border border-gray-300 hover:bg-gray-50"
                onClick={() => setBulkDeleteConfirm(false)}
                disabled={isDeleting}
              >
                Cancel
              </button>
              <button
                className="px-4 py-2 text-sm rounded-md bg-red-600 text-white hover:bg-red-700 disabled:opacity-50"
                onClick={deleteBulk}
                disabled={isDeleting}
              >
                {isDeleting ? 'Deleting...' : `Delete ${selectedRows.size}`}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Bulk action bar */}
      {selectedRows.size > 0 && (
        <div className="mb-3 flex items-center gap-3 rounded-lg bg-blue-50 px-4 py-2 shadow-sm">
          <span className="text-sm text-blue-700 font-medium">{selectedRows.size} selected</span>
          <button
            className="flex items-center gap-1 px-3 py-1.5 text-sm rounded-md bg-red-600 text-white hover:bg-red-700"
            onClick={() => setBulkDeleteConfirm(true)}
          >
            <TrashIcon className="h-4 w-4" /> Delete Selected
          </button>
          <button
            className="text-sm text-gray-500 hover:text-gray-700 underline"
            onClick={() => { setSelectedRows(new Set()); setSelectAll(false); }}
          >
            Clear
          </button>
        </div>
      )}

      <div className="inline-block min-w-full align-middle">
        <div className="rounded-xl bg-white shadow-sm ring-1 ring-gray-100">
          <div className="max-h-[600px] overflow-y-auto">
            <table className="hidden min-w-full text-gray-900 md:table table-fixed">
              <colgroup>
                <col className="w-[40px]" />
                <col className="w-[140px]" />
                <col className="w-[100px]" />
                <col className="w-[110px]" />
                <col className="w-[130px]" />
                <col className="w-[130px]" />
                <col className="w-[90px]" />
              </colgroup>
              <thead className="rounded-lg text-left text-sm font-bold sticky top-0 bg-white z-10 after:absolute after:left-0 after:right-0 after:bottom-0 after:h-px after:bg-gray-200">
                <tr>
                  <th scope="col" className="px-2 py-3">
                    <div className="flex items-center justify-center">
                      <input
                        type="checkbox"
                        className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500 focus:ring-offset-0"
                        checked={selectAll}
                        onChange={handleSelectAll}
                      />
                    </div>
                  </th>
                  <th
                    scope="col"
                    className="px-2 py-3 font-bold cursor-pointer hover:bg-gray-50 group whitespace-nowrap"
                    onClick={() => handleSort('so_number')}
                  >
                    <div className="flex items-center">
                      <span className="text-gray-900">SO Number</span>
                      <div className="ml-1 opacity-0 group-hover:opacity-100">{renderSortIcon('so_number')}</div>
                    </div>
                  </th>
                  <th
                    scope="col"
                    className="px-2 py-3 font-bold cursor-pointer hover:bg-gray-50 group whitespace-nowrap"
                    onClick={() => handleSort('vender')}
                  >
                    <div className="flex items-center">
                      <span className="text-gray-900">Vender</span>
                      <div className="ml-1 opacity-0 group-hover:opacity-100">{renderSortIcon('vender')}</div>
                    </div>
                  </th>
                  <th
                    scope="col"
                    className="px-2 py-3 font-bold cursor-pointer hover:bg-gray-50 group whitespace-nowrap"
                    onClick={() => handleSort('date')}
                  >
                    <div className="flex items-center">
                      <span className="text-gray-900">Date</span>
                      <div className="ml-1 opacity-0 group-hover:opacity-100">{renderSortIcon('date')}</div>
                    </div>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold whitespace-nowrap">
                    <span className="text-gray-900">Payload</span>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold whitespace-nowrap">
                    <span className="text-gray-900">Licence</span>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold whitespace-nowrap">
                    <span className="text-gray-900">Actions</span>
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 text-sm">
                {sos.map((so) => (
                  <tr
                    key={String(so.id)}
                    className="group relative transition-colors hover:bg-blue-50 cursor-pointer"
                    style={{ height: '52px' }}
                    onClick={(e) => {
                      const target = e.target as HTMLElement;
                      if (target.closest('input[type="checkbox"]') || target.closest('button[data-action]')) return;
                      router.push(`/dashboard/so/${so.id}/edit`);
                    }}
                  >
                    <td className="whitespace-nowrap px-2 py-3" onClick={(e) => e.stopPropagation()}>
                      <div className="flex items-center justify-center">
                        <input
                          type="checkbox"
                          className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500 focus:ring-offset-0"
                          checked={selectedRows.has(String(so.id))}
                          onChange={() => handleSelectRow(so.id)}
                        />
                      </div>
                    </td>
                    <td className="whitespace-nowrap px-2 py-3 text-sm font-semibold text-blue-700 bg-blue-50 rounded-lg shadow-sm border border-blue-100">
                      {so.so_number}
                    </td>
                    <td className="whitespace-nowrap px-2 py-3 text-sm text-gray-700">
                      {so.vender || '-'}
                    </td>
                    <td className="whitespace-nowrap px-2 py-3 text-sm text-gray-700">
                      {so.date}
                    </td>
                    <td className="whitespace-nowrap px-2 py-3 text-sm text-gray-700">
                      {so.payload_number || '-'}
                    </td>
                    <td className="whitespace-nowrap px-2 py-3 text-sm text-gray-700">
                      {so.licence_number || '-'}
                    </td>
                    <td className="whitespace-nowrap px-2 py-3 text-sm" onClick={(e) => e.stopPropagation()}>
                      <div className="flex items-center gap-2">
                        <button
                          data-action
                          className="p-1.5 rounded hover:bg-blue-100 text-blue-600 transition-colors"
                          title="Edit"
                          onClick={() => router.push(`/dashboard/so/${so.id}/edit`)}
                        >
                          <PencilIcon className="h-4 w-4" />
                        </button>
                        <button
                          data-action
                          className="p-1.5 rounded hover:bg-red-100 text-red-500 transition-colors"
                          title="Delete"
                          onClick={() => setDeleteConfirm({ open: true, id: String(so.id) })}
                        >
                          <TrashIcon className="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
                {sos.length === 0 && (
                  <tr>
                    <td colSpan={7} className="py-12 text-center text-sm text-gray-400">
                      No SO records found.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}
