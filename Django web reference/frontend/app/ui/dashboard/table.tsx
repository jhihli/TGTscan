"use client"

import { ArrowUpIcon, ArrowDownIcon, ChevronRightIcon, ChevronDownIcon } from '@heroicons/react/24/outline';
import { getProducts, fetchProductsTotalPage } from '@/app/lib/data';
import { Product } from "@/interface/IDatatable"
import { useState, useEffect, createContext, useContext, useRef, useMemo } from 'react';
import { deleteProducts } from '@/app/lib/actions';
import { useRouter } from 'next/navigation';
import Lightbox from "yet-another-react-lightbox";
import "yet-another-react-lightbox/styles.css";
import Zoom from "yet-another-react-lightbox/plugins/zoom";
import Fullscreen from "yet-another-react-lightbox/plugins/fullscreen";
import Download from "yet-another-react-lightbox/plugins/download";

// ─── Context ────────────────────────────────────────────────────────────────

export const DeleteMessageContext = createContext<{
  deleteMessage: string | null;
  setDeleteMessage: (message: string | null) => void;
  isMessageVisible: boolean;
  setIsMessageVisible: (visible: boolean) => void;
}>({
  deleteMessage: null,
  setDeleteMessage: () => {},
  isMessageVisible: false,
  setIsMessageVisible: () => {},
});

export function DeleteMessageProvider({ children }: { children: React.ReactNode }) {
  const [deleteMessage, setDeleteMessage] = useState<string | null>(null);
  const [isMessageVisible, setIsMessageVisible] = useState(false);

  useEffect(() => {
    if (deleteMessage) {
      setIsMessageVisible(true);
      const timer = setTimeout(() => {
        setIsMessageVisible(false);
        setTimeout(() => setDeleteMessage(null), 500);
      }, 5000);
      return () => clearTimeout(timer);
    }
  }, [deleteMessage]);

  return (
    <DeleteMessageContext.Provider value={{ deleteMessage, setDeleteMessage, isMessageVisible, setIsMessageVisible }}>
      {children}
    </DeleteMessageContext.Provider>
  );
}

export function useDeleteMessage() {
  return useContext(DeleteMessageContext);
}

export function DeleteMessage() {
  const { deleteMessage, isMessageVisible } = useDeleteMessage();
  if (!deleteMessage) return null;
  return (
    <div className={`ml-4 p-2 rounded-md transition-opacity duration-500 ${isMessageVisible ? 'opacity-100' : 'opacity-0'} ${deleteMessage.includes('success') ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
      {deleteMessage}
    </div>
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const notifySelectedItemsChanged = () => {
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new Event('selectedItemsChanged'));
  }
};

function isPalletProduct(p: Product): boolean {
  return !p.barcode && !p.number && !p.category;
}

interface PalletGroup {
  groupKey: string;       // pallet product ID, or 'so_<soKey>' for legacy boards with no pallet FK
  soKey: string;          // so_number_str for display
  palletProduct: Product | null;
  boardProducts: Product[];
}

// ─── Photo dialog ─────────────────────────────────────────────────────────────

function PhotoCell({ photos }: { photos: Product['photos'] }) {
  const [open, setOpen] = useState(false);
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const [lightboxIndex, setLightboxIndex] = useState(0);

  const urls = useMemo(() => {
    if (!Array.isArray(photos) || photos.length === 0) return [];
    if (typeof photos[0] === 'string') return photos as unknown as string[];
    return (photos as unknown as Record<string, any>[])
      .map(p => p.url || p.path || p.image || p.src || p.file || '')
      .filter((u): u is string => typeof u === 'string' && u.length > 0);
  }, [photos]);

  if (urls.length === 0) return null;

  return (
    <>
      <button
        data-photo
        className="underline text-blue-600 hover:text-blue-800 focus:outline-none px-2 py-1 rounded hover:bg-blue-100 transition-colors"
        onClick={e => { e.stopPropagation(); setOpen(true); }}
      >
        Show
      </button>

      {open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-white rounded-xl shadow-2xl max-w-6xl w-full max-h-[90vh] overflow-hidden relative">
            <div className="sticky top-0 bg-gradient-to-r from-blue-50 to-indigo-50 px-6 py-4 border-b border-gray-200 flex items-center justify-between">
              <h3 className="text-lg font-semibold text-gray-800">
                產品照片 <span className="text-sm font-normal text-gray-600">({urls.length} 張)</span>
              </h3>
              <button
                className="flex items-center justify-center w-8 h-8 rounded-full hover:bg-gray-200 transition-colors text-gray-500"
                onClick={() => setOpen(false)}
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <div className="p-6 overflow-y-auto" style={{ maxHeight: 'calc(90vh - 80px)' }}>
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                {urls.map((url, idx) => (
                  <div
                    key={idx}
                    className="group relative bg-white rounded-lg overflow-hidden shadow-md hover:shadow-2xl cursor-pointer transition-all duration-300 hover:-translate-y-1"
                    onClick={() => { setLightboxIndex(idx); setLightboxOpen(true); }}
                  >
                    <div className="relative aspect-square bg-gray-100">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={url} alt={`photo-${idx}`} className="absolute inset-0 w-full h-full object-cover transition-transform duration-300 group-hover:scale-110" />
                      <div className="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-all duration-300 flex items-center justify-center">
                        <div className="opacity-0 group-hover:opacity-100 text-white flex flex-col items-center gap-2">
                          <svg className="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7" />
                          </svg>
                          <span className="text-sm font-medium">點擊放大</span>
                        </div>
                      </div>
                    </div>
                    <div className="absolute top-2 right-2 bg-black/70 text-white text-xs font-semibold px-2 py-1 rounded-full">#{idx + 1}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      <Lightbox
        open={lightboxOpen}
        close={() => setLightboxOpen(false)}
        index={lightboxIndex}
        slides={urls.map(url => ({ src: url, download: url }))}
        plugins={[Zoom, Fullscreen, Download]}
        zoom={{ maxZoomPixelRatio: 3, scrollToZoom: true, doubleClickDelay: 300, doubleClickMaxStops: 2 }}
        controller={{ closeOnBackdropClick: true, closeOnPullDown: true }}
        on={{ view: ({ index }) => setLightboxIndex(index) }}
        carousel={{ finite: false, preload: 2 }}
      />
    </>
  );
}

function NoteCell({ noted }: { noted: string }) {
  const [open, setOpen] = useState(false);
  if (!noted || noted.trim() === '') return null;
  return (
    <>
      <button
        data-note
        className="underline text-blue-600 hover:text-blue-800 focus:outline-none px-2 py-1 rounded hover:bg-blue-100 transition-colors"
        onClick={e => { e.stopPropagation(); setOpen(true); }}
      >
        Show
      </button>
      {open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30">
          <div className="bg-white rounded-lg shadow-lg max-w-md w-full p-6 relative">
            <button className="absolute top-2 right-2 text-gray-400 hover:text-gray-700 text-xl font-bold" onClick={() => setOpen(false)}>×</button>
            <div className="text-base font-semibold mb-2 text-gray-800">備註內容</div>
            <div className="text-sm text-gray-700 whitespace-pre-line break-words max-h-80 overflow-y-auto">{noted}</div>
          </div>
        </div>
      )}
    </>
  );
}

// ─── Main component ───────────────────────────────────────────────────────────

export default function ProductsTable({
  initialProducts,
  query,
  currentPage,
}: {
  initialProducts: Product[];
  query: string;
  currentPage: number;
}) {
  const router = useRouter();
  const [products, setProducts] = useState<Product[]>(initialProducts);
  const [selectedRows, setSelectedRows] = useState<Set<string>>(new Set());
  const [selectAll, setSelectAll] = useState(false);
  const [totalPages, setTotalPages] = useState(1);
  const [allBoardIds, setAllBoardIds] = useState<string[]>([]);
  const { setDeleteMessage } = useDeleteMessage();
  const initialLoadRef = useRef(true);
  const prevSelectedRowsRef = useRef<string[]>([]);
  const [sortField, setSortField] = useState<string>('');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [expandedGroups, setExpandedGroups] = useState<Set<string>>(new Set());

  // Group products by pallet product ID (board → pallet FK), or SO string for legacy boards
  const palletGroups = useMemo<PalletGroup[]>(() => {
    const map = new Map<string, PalletGroup>();
    for (const p of products) {
      if (isPalletProduct(p)) {
        const key = String(p.id);
        if (!map.has(key)) {
          map.set(key, { groupKey: key, soKey: p.so_number_str || '__no_so__', palletProduct: p, boardProducts: [] });
        } else {
          map.get(key)!.palletProduct = p;
        }
      } else {
        const key = p.pallet ? String(p.pallet) : `so_${p.so_number_str || '__no_so__'}`;
        if (!map.has(key)) {
          map.set(key, { groupKey: key, soKey: p.so_number_str || '__no_so__', palletProduct: null, boardProducts: [] });
        }
        map.get(key)!.boardProducts.push(p);
      }
    }
    return Array.from(map.values());
  }, [products]);

  const toggleExpand = (groupKey: string) => {
    setExpandedGroups(prev => {
      const next = new Set(prev);
      next.has(groupKey) ? next.delete(groupKey) : next.add(groupKey);
      return next;
    });
  };

  // Cache products to localStorage
  const cacheProducts = (fetched: Product[]) => {
    if (!Array.isArray(fetched)) return;
    const map: Record<string, any> = {};
    fetched.forEach(prod => {
      map[String(prod.id)] = {
        ...prod,
        current_status: prod.current_status !== undefined && prod.current_status !== null ? prod.current_status : '0',
      };
    });
    try { localStorage.setItem('allProductsMap', JSON.stringify(map)); } catch {}
  };

  // Initial fetch
  useEffect(() => {
    const fetchInitialData = async () => {
      try {
        const [fetched, total] = await Promise.all([
          getProducts(query, currentPage),
          fetchProductsTotalPage(query),
        ]);
        setProducts(fetched);
        setTotalPages(total);
        cacheProducts(fetched);
      } catch (error) {
        console.error('Failed to fetch initial data:', error);
      }
    };
    fetchInitialData();
  }, [query, currentPage]);

  // Load selected rows from localStorage
  useEffect(() => {
    try {
      const stored = JSON.parse(localStorage.getItem('selectedProductIds') || '[]');
      setSelectedRows(new Set(stored));
      prevSelectedRowsRef.current = stored;
    } catch {
      setSelectedRows(new Set());
    }

    const handleExternalChange = (event: Event) => {
      if ((event as CustomEvent)?.detail?.source !== 'table') {
        try {
          const stored = JSON.parse(localStorage.getItem('selectedProductIds') || '[]');
          setSelectedRows(new Set(stored));
          setSelectAll(false);
        } catch {
          setSelectedRows(new Set());
        }
      }
    };
    window.addEventListener('selectedItemsChanged', handleExternalChange);
    return () => window.removeEventListener('selectedItemsChanged', handleExternalChange);
  }, []);

  // Sync selected rows to localStorage
  useEffect(() => {
    if (initialLoadRef.current) { initialLoadRef.current = false; return; }
    const current = Array.from(selectedRows);
    const prev = prevSelectedRowsRef.current;
    if (JSON.stringify(current) !== JSON.stringify(prev)) {
      try {
        localStorage.setItem('selectedProductIds', JSON.stringify(current));
        prevSelectedRowsRef.current = current;
        window.dispatchEvent(new CustomEvent('selectedItemsChanged', { detail: { source: 'table' } }));
      } catch {}
    }
  }, [selectedRows]);

  // Refresh after deletion
  useEffect(() => {
    const handleDeletionRefresh = async () => {
      try {
        const [fetched, total] = await Promise.all([
          getProducts(query, currentPage),
          fetchProductsTotalPage(query),
        ]);
        setProducts(fetched);
        setTotalPages(total);
        cacheProducts(fetched);
      } catch (error) {
        console.error('Failed to refresh products after deletion:', error);
      }
    };
    window.addEventListener('selectedItemsChanged', handleDeletionRefresh);
    return () => window.removeEventListener('selectedItemsChanged', handleDeletionRefresh);
  }, [query, currentPage]);

  // Re-fetch on sort/page change
  useEffect(() => {
    const fetchData = async () => {
      try {
        const [fetched, total] = await Promise.all([
          getProducts(query, currentPage, sortField, sortOrder),
          fetchProductsTotalPage(query),
        ]);
        setProducts(fetched);
        setTotalPages(total);
      } catch (error) {
        console.error('Failed to fetch products:', error);
      }
    };
    fetchData();
  }, [query, currentPage, sortField, sortOrder]);

  // Fetch all board IDs for select-all
  const fetchAllBoardIds = async () => {
    try {
      const allIds: string[] = [];
      for (let page = 1; page <= totalPages; page++) {
        const pageProducts = await getProducts(query, page);
        pageProducts
          .filter(p => !isPalletProduct(p))
          .forEach(p => allIds.push(String(p.id)));
      }
      setAllBoardIds(allIds);
      return allIds;
    } catch {
      return [];
    }
  };

  const handleSelectAll = async () => {
    if (selectAll) {
      setSelectedRows(new Set());
    } else {
      const ids = await fetchAllBoardIds();
      setSelectedRows(new Set(ids));
    }
    setSelectAll(!selectAll);
  };

  const handleSelectRow = (id: bigint | string) => {
    const stringId = String(id);
    const next = new Set(selectedRows);
    next.has(stringId) ? next.delete(stringId) : next.add(stringId);
    setSelectedRows(next);
    setSelectAll(false);
  };

  const handleSort = async (field: string) => {
    let newOrder: 'asc' | 'desc' = 'asc';
    if (field === 'current_status') {
      newOrder = sortField === field && sortOrder === 'asc' ? 'desc' : 'asc';
      setSortField(field);
      setSortOrder(newOrder);
      const sorted = [...products].sort((a, b) => {
        const aVal = a.current_status === '1' ? 0 : 1;
        const bVal = b.current_status === '1' ? 0 : 1;
        return newOrder === 'asc' ? aVal - bVal : bVal - aVal;
      });
      setProducts(sorted);
      return;
    }
    newOrder = field === sortField && sortOrder === 'asc' ? 'desc' : 'asc';
    setSortField(field);
    setSortOrder(newOrder);
    try {
      const sorted = await getProducts(query, currentPage, field, newOrder);
      setProducts(sorted);
    } catch {}
  };

  const renderSortIcon = (field: string) => {
    if (sortField !== field) return null;
    return sortOrder === 'asc' ? <ArrowUpIcon className="h-4 w-4 ml-1" /> : <ArrowDownIcon className="h-4 w-4 ml-1" />;
  };

  // ─── Render ─────────────────────────────────────────────────────────────────

  return (
    <div className="mt-6 flow-root">
      <div className="inline-block min-w-full align-middle">
        <div className="rounded-xl bg-white shadow-sm ring-1 ring-gray-100">
          <div className="max-h-[600px] overflow-y-auto">
            <table className="hidden min-w-full text-gray-900 md:table table-fixed">
              <colgroup>
                <col className="w-[32px]"/>
                <col className="w-[32px]"/>
                <col className="w-[55px]"/>
                <col className="w-[105px]"/>
                <col className="w-[105px]"/>
                <col className="w-[105px]"/>
                <col className="w-[82px]"/>
                <col className="w-[80px]"/>
                <col className="w-[105px]"/>
                <col className="w-[65px]"/>
                <col className="w-[55px]"/>
                <col className="w-[82px]"/>
                <col className="w-[115px]"/>
                <col className="w-[65px]"/>
                <col className="w-[82px]"/>
                <col className="w-[62px]"/>
                <col className="w-[52px]"/>
                <col className="w-[50px]"/>
              </colgroup>
              <thead className="rounded-lg text-left text-sm font-bold sticky top-0 bg-white z-10 after:absolute after:left-0 after:right-0 after:bottom-0 after:h-px after:bg-gray-200">
                <tr>
                  <th scope="col" className="px-1 py-3" />
                  <th scope="col" className="px-1 py-3">
                    <div className="flex items-center justify-center">
                      <input
                        type="checkbox"
                        className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500 focus:ring-offset-0"
                        checked={selectAll}
                        onChange={handleSelectAll}
                      />
                    </div>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold cursor-pointer hover:bg-gray-50 group whitespace-nowrap" onClick={() => handleSort('id')}>
                    <div className="flex items-center"><span>ID</span><div className="ml-1 opacity-0 group-hover:opacity-100">{renderSortIcon('id')}</div></div>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold cursor-pointer hover:bg-gray-50 group whitespace-nowrap" onClick={() => handleSort('so_number')}>
                    <div className="flex items-center"><span>SO Number</span><div className="ml-1 opacity-0 group-hover:opacity-100">{renderSortIcon('so_number')}</div></div>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold whitespace-nowrap">Licence</th>
                  <th scope="col" className="px-2 py-3 font-bold whitespace-nowrap">Payload</th>
                  <th scope="col" className="px-2 py-3 font-bold cursor-pointer hover:bg-gray-50 group whitespace-nowrap" onClick={() => handleSort('so_number__date')}>
                    <div className="flex items-center"><span>Date</span><div className="ml-1 opacity-0 group-hover:opacity-100">{renderSortIcon('so_number__date')}</div></div>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold whitespace-nowrap">Vender</th>
                  <th scope="col" className="px-2 py-3 font-bold cursor-pointer hover:bg-gray-50 group whitespace-nowrap" onClick={() => handleSort('number')}>
                    <div className="flex items-center"><span>Number</span><div className="ml-1 opacity-0 group-hover:opacity-100">{renderSortIcon('number')}</div></div>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold cursor-pointer hover:bg-gray-50 group whitespace-nowrap" onClick={() => handleSort('weight')}>
                    <div className="flex items-center"><span>Weight</span><div className="ml-1 opacity-0 group-hover:opacity-100">{renderSortIcon('weight')}</div></div>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold cursor-pointer hover:bg-gray-50 group whitespace-nowrap" onClick={() => handleSort('qty')}>
                    <div className="flex items-center"><span>Qty</span><div className="ml-1 opacity-0 group-hover:opacity-100">{renderSortIcon('qty')}</div></div>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold cursor-pointer hover:bg-gray-50 group whitespace-nowrap" onClick={() => handleSort('catalog_name')}>
                    <div className="flex items-center"><span>Catalog</span><div className="ml-1 opacity-0 group-hover:opacity-100">{renderSortIcon('catalog_name')}</div></div>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold cursor-pointer hover:bg-gray-50 group whitespace-nowrap" onClick={() => handleSort('barcode')}>
                    <div className="flex items-center"><span>Barcode</span><div className="ml-1 opacity-0 group-hover:opacity-100">{renderSortIcon('barcode')}</div></div>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold cursor-pointer hover:bg-gray-50 group whitespace-nowrap" onClick={() => handleSort('chip_qty')}>
                    <div className="flex items-center"><span>Chip Qty</span><div className="ml-1 opacity-0 group-hover:opacity-100">{renderSortIcon('chip_qty')}</div></div>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold cursor-pointer hover:bg-gray-50 group whitespace-nowrap" onClick={() => handleSort('ex_date')}>
                    <div className="flex items-center"><span>Ship Date</span><div className="ml-1 opacity-0 group-hover:opacity-100">{renderSortIcon('ex_date')}</div></div>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold cursor-pointer hover:bg-gray-50 group whitespace-nowrap" onClick={() => handleSort('current_status')}>
                    <div className="flex items-center"><span>Status</span><div className="ml-1 opacity-0 group-hover:opacity-100">{renderSortIcon('current_status')}</div></div>
                  </th>
                  <th scope="col" className="px-2 py-3 font-bold whitespace-nowrap">Photo</th>
                  <th scope="col" className="px-2 py-3 font-bold whitespace-nowrap">Note</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 text-sm">
                {palletGroups.map(({ groupKey, soKey, palletProduct, boardProducts }) => {
                  const isExpanded = expandedGroups.has(groupKey);
                  const representative = palletProduct ?? boardProducts[0];
                  if (!representative) return null;

                  return (
                    <PalletGroupRows
                      key={groupKey}
                      groupKey={groupKey}
                      soKey={soKey}
                      palletProduct={palletProduct}
                      boardProducts={boardProducts}
                      representative={representative}
                      isExpanded={isExpanded}
                      onToggleExpand={() => toggleExpand(groupKey)}
                      selectedRows={selectedRows}
                      onSelectRow={handleSelectRow}
                      router={router}
                    />
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Pallet group rows ────────────────────────────────────────────────────────

function PalletGroupRows({
  groupKey,
  soKey,
  palletProduct,
  boardProducts,
  representative,
  isExpanded,
  onToggleExpand,
  selectedRows,
  onSelectRow,
  router,
}: {
  groupKey: string;
  soKey: string;
  palletProduct: Product | null;
  boardProducts: Product[];
  representative: Product;
  isExpanded: boolean;
  onToggleExpand: () => void;
  selectedRows: Set<string>;
  onSelectRow: (id: bigint | string) => void;
  router: ReturnType<typeof useRouter>;
}) {
  return (
    <>
      {/* ── Pallet row (group label — not selectable/deletable) ── */}
      <tr
        className="cursor-pointer select-none border-l-4 border-amber-400 bg-amber-50 hover:bg-amber-100 transition-colors"
        style={{ height: '52px' }}
        onClick={onToggleExpand}
      >
        {/* expand toggle */}
        <td className="px-1 py-2 text-amber-600">
          <div className="flex items-center justify-center">
            {isExpanded ? <ChevronDownIcon className="h-4 w-4" /> : <ChevronRightIcon className="h-4 w-4" />}
          </div>
        </td>
        {/* no checkbox */}
        <td className="px-1 py-2" />
        {/* ID */}
        <td className="whitespace-nowrap px-2 py-2 text-xs text-amber-700 font-medium">
          {palletProduct ? palletProduct.id : '—'}
        </td>
        {/* SO Number */}
        <td className="whitespace-nowrap px-2 py-2">
          <span className="inline-block text-sm font-bold text-blue-700 bg-blue-50 rounded-lg shadow-sm border border-blue-100 px-2 py-0.5">
            {soKey === '__no_so__' || soKey.startsWith('so_') ? (soKey.startsWith('so_') ? soKey.slice(3) : '—') : soKey}
          </span>
          {boardProducts.length > 0 && (
            <span className="ml-1 text-xs text-amber-600 font-semibold">({boardProducts.length})</span>
          )}
        </td>
        {/* Licence */}
        <td className="whitespace-nowrap px-2 py-2 text-sm text-amber-800">{representative.so_licence_number || '—'}</td>
        {/* Payload */}
        <td className="whitespace-nowrap px-2 py-2 text-sm text-amber-800">{representative.so_payload_number || '—'}</td>
        {/* Date */}
        <td className="whitespace-nowrap px-2 py-2 text-sm text-amber-800">{representative.so_date || '—'}</td>
        {/* Vender */}
        <td className="whitespace-nowrap px-2 py-2 text-sm text-amber-800">{representative.so_vender || '—'}</td>
        {/* Number */}
        <td className="px-2 py-2 text-xs text-gray-400">—</td>
        {/* Weight — per-pallet from product */}
        <td className="whitespace-nowrap px-2 py-2 text-sm text-amber-800">
          {palletProduct?.pallet_weight != null ? palletProduct.pallet_weight : '—'}
        </td>
        {/* Qty — per-pallet from product */}
        <td className="whitespace-nowrap px-2 py-2 text-sm text-amber-800">
          {palletProduct?.pallet_qty != null ? palletProduct.pallet_qty : '—'}
        </td>
        {/* Catalog */}
        <td className="px-2 py-2 text-xs text-gray-400">—</td>
        {/* Barcode */}
        <td className="px-2 py-2 text-xs text-gray-400">—</td>
        {/* Chip Qty */}
        <td className="px-2 py-2 text-xs text-gray-400">—</td>
        {/* Ship Date */}
        <td className="px-2 py-2 text-xs text-gray-400">—</td>
        {/* Status */}
        <td className="px-2 py-2 text-xs text-gray-400">—</td>
        {/* Photo */}
        <td className="whitespace-nowrap px-2 py-2" onClick={e => e.stopPropagation()}>
          {palletProduct && <PhotoCell photos={palletProduct.photos} />}
        </td>
        {/* Note */}
        <td className="whitespace-nowrap px-2 py-2" onClick={e => e.stopPropagation()}>
          {palletProduct && <NoteCell noted={palletProduct.noted || ''} />}
        </td>
      </tr>

      {/* ── Board rows (visible only when expanded) ── */}
      {isExpanded && boardProducts.map(product => (
        <tr
          key={String(product.id)}
          className="group transition-colors hover:bg-blue-50 cursor-pointer bg-white border-l-4 border-transparent"
          style={{ height: '56px' }}
          onClick={e => {
            const target = e.target as HTMLElement;
            if (target.closest('input[type="checkbox"]') || target.closest('[data-photo]') || target.closest('[data-note]')) return;
            router.push(`/dashboard/${product.id}/edit`);
          }}
        >
          {/* indent (no toggle) */}
          <td className="px-1 py-2" />
          {/* checkbox */}
          <td className="whitespace-nowrap px-2 py-2" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-center">
              <input
                type="checkbox"
                className="h-5 w-5 rounded border-gray-300 text-blue-600 focus:ring-blue-500 focus:ring-offset-0 transition-all duration-200"
                checked={selectedRows.has(String(product.id))}
                onChange={() => onSelectRow(product.id)}
              />
            </div>
          </td>
          {/* ID */}
          <td className="whitespace-nowrap px-2 py-2 text-sm text-gray-700">{product.id}</td>
          {/* SO Number — dimmed, contextual */}
          <td className="whitespace-nowrap px-2 py-2 text-xs text-gray-400">{product.so_number_str || '—'}</td>
          {/* Licence */}
          <td className="whitespace-nowrap px-2 py-2 text-sm text-gray-400">{product.so_licence_number || '—'}</td>
          {/* Payload */}
          <td className="whitespace-nowrap px-2 py-2 text-sm text-gray-400">{product.so_payload_number || '—'}</td>
          {/* Date */}
          <td className="whitespace-nowrap px-2 py-2 text-sm text-gray-400">{product.so_date || '—'}</td>
          {/* Vender */}
          <td className="whitespace-nowrap px-2 py-2 text-sm text-gray-400">{product.so_vender || '—'}</td>
          {/* Number */}
          <td className="whitespace-nowrap px-2 py-2 text-sm text-gray-700">{product.number}</td>
          {/* Weight */}
          <td className="whitespace-nowrap px-2 py-2 text-sm text-gray-700">{product.weight}</td>
          {/* Qty */}
          <td className="whitespace-nowrap px-2 py-2 text-sm text-gray-700">{product.qty ?? '—'}</td>
          {/* Catalog */}
          <td className="whitespace-nowrap px-2 py-2 text-sm text-gray-700">{product.catalog_name || '—'}</td>
          {/* Barcode */}
          <td className="whitespace-nowrap px-2 py-2 text-sm text-gray-700">{product.barcode}</td>
          {/* Chip Qty */}
          <td className="whitespace-nowrap px-2 py-2 text-sm text-gray-700">{product.chip_qty ?? '—'}</td>
          {/* Ship Date */}
          <td className="whitespace-nowrap px-2 py-2 text-sm text-gray-700">{product.ex_date}</td>
          {/* Status */}
          <td
            className="whitespace-nowrap px-2 py-2 text-sm font-bold rounded-lg shadow-sm border border-green-200"
            style={{
              color: product.current_status === '0' ? '#15803d' : product.current_status === '1' ? '#b91c1c' : '#0f172a',
              background: product.current_status === '0' ? '#dcfce7' : product.current_status === '1' ? '#fee2e2' : '#f1f5f9',
            }}
          >
            {product.current_status === '0' ? '入庫' : product.current_status === '1' ? '出貨' : product.current_status}
          </td>
          {/* Photo */}
          <td className="whitespace-nowrap px-2 py-2">
            <PhotoCell photos={product.photos} />
          </td>
          {/* Note */}
          <td className="whitespace-nowrap px-2 py-2">
            <NoteCell noted={product.noted || ''} />
          </td>
        </tr>
      ))}
    </>
  );
}
