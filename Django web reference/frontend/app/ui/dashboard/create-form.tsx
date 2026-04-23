"use client"
import Link from 'next/link';
import { Button } from '@/app/ui/button';
import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { createProduct } from '@/app/lib/actions';
import { PencilSquareIcon, PlusIcon, TrashIcon, XMarkIcon } from '@heroicons/react/24/outline';
import { lusitana } from '@/app/ui/fonts';
import Dialog from '@/app/ui/dialog';
import { getCargos, getCatalogs } from '@/app/lib/data';
import { Cargo, Catalog } from '@/interface/IDatatable';
import SearchableSelect from '@/app/ui/SearchableSelect';
import AsyncSearchableSelect, { AsyncOption } from '@/app/ui/AsyncSearchableSelect';

// 1. 擴充 TempProduct 型別
interface TempProduct {
  id: string;
  number: string;
  so_number_id: string;   // SO primary key (sent to API)
  so_number_str: string;  // SO.so_number (display)
  so_vender: string;
  so_date: string;
  so_licence_number: string;
  so_payload_number: string;
  barcode: string;
  qty: string;
  weight: string;
  chip_qty: string;
  client: string;
  category: string;
  current_status: string;
  noted: string;
  photos: File[];
  cargo?: string;
  catalog?: string;
}

export default function Form() {

  const router = useRouter();
  const searchParams = useSearchParams();

  const [numberItems, setNumberItems] = useState<{number: string}[]>([{number: ''}]);
  const [palletQty, setPalletQty] = useState('');
  const [barcode, setBarcode] = useState('');
  const [client, setClient] = useState('');
  const [category, setCategory] = useState('0');
  const [photos, setPhotos] = useState<File[]>([]);
  const [soId, setSoId] = useState('');          // selected SO's PK
  const [soStr, setSoStr] = useState('');         // SO.so_number display
  const [soVender, setSoVender] = useState('');   // read-only from SO
  const [soDate, setSoDate] = useState('');       // read-only from SO

  const [soLicenceNumber, setSoLicenceNumber] = useState('');
  const [soPayloadNumber, setSoPayloadNumber] = useState('');
  const [soError, setSoError] = useState('');
  const [weight, setWeight] = useState('');
  const [chipQty, setChipQty] = useState('');
  const [current_status, setCurrentStatus] = useState('0');
  const [noted, setNoted] = useState('');
  const [cargo, setCargo] = useState('');
  const [cargos, setCargos] = useState<Cargo[]>([]);
  const [catalogId, setCatalogId] = useState('');
  const [catalogs, setCatalogs] = useState<Catalog[]>([]);
  const [weightError, setWeightError] = useState('');

  // Add state for temporary products
  const [tempProducts, setTempProducts] = useState<TempProduct[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);
  const [detailDialogOpen, setDetailDialogOpen] = useState(false);
  const [detailProduct, setDetailProduct] = useState<TempProduct | null>(null);

  // Fetch cargos and catalogs on mount
  useEffect(() => {
    Promise.all([getCargos(), getCatalogs()]).then(([c, cat]) => {
      setCargos(c);
      setCatalogs(cat);
    });
  }, []);

  // Fetch SOs from backend matching the search term (used by AsyncSearchableSelect)
  const fetchSOs = async (search: string): Promise<AsyncOption[]> => {
    const API_URL = process.env.NEXT_PUBLIC_Django_API_URL;
    try {
      const res = await fetch(
        `${API_URL}/product/sos/?search=${encodeURIComponent(search)}&limit=20`,
        { headers: { 'X-API-Key': process.env.NEXT_PUBLIC_API_KEY || '' } }
      );
      if (!res.ok) return [];
      const data = await res.json();
      return data.map((s: { id: string | bigint; so_number: string; vender: string; date: string; licence_number: string; payload_number: string }) => ({
        id: s.id,
        name: s.so_number,
        vender: s.vender,
        date: s.date,
        licence_number: s.licence_number,
        payload_number: s.payload_number,
      }));
    } catch {
      return [];
    }
  };

  // Handle SO selection — auto-fill vender/date/licence/payload from the selected SO
  const handleSoSelectFull = (option: AsyncOption | null) => {
    setSoError('');
    if (option) {
      setSoId(String(option.id));
      setSoStr(option.name);
      setSoVender(String(option.vender ?? ''));
      setSoDate(String(option.date ?? ''));
      setSoLicenceNumber(String(option.licence_number ?? ''));
      setSoPayloadNumber(String(option.payload_number ?? ''));
    } else {
      setSoId('');
      setSoStr('');
      setSoVender('');
      setSoDate('');
      setSoLicenceNumber('');
      setSoPayloadNumber('');
    }
  };

  // Handle client change and update URL
  const handleClientChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setClient(value);

    const params = new URLSearchParams(searchParams);
    if (value) {
      params.set('client', value);
    } else {
      params.delete('client');
    }
    router.push(`?${params.toString()}`);
  };

  // Handle weight change with validation
  const handleWeightChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;

    // Allow empty value
    if (value === '') {
      setWeight('');
      setWeightError('');
      return;
    }

    // Check if value is a valid number (allow decimals)
    if (!/^\d+\.?\d*$/.test(value)) {
      setWeightError('Weight must be a number');
      return;
    }

    // Remove leading zeros (e.g., '00222' becomes '222', '00.5' becomes '0.5')
    let cleanedValue = value;

    // If value starts with zeros followed by a decimal point, keep one zero (e.g., '00.5' -> '0.5')
    if (/^0+\./.test(value)) {
      cleanedValue = value.replace(/^0+/, '0');
    }
    // If value is all zeros followed by digits, remove leading zeros (e.g., '00222' -> '222')
    else if (/^0+\d/.test(value)) {
      cleanedValue = value.replace(/^0+/, '');
    }
    // If value is just zeros, keep one zero
    else if (/^0+$/.test(value)) {
      cleanedValue = '0';
    }

    setWeight(cleanedValue);
    setWeightError('');
  };

  // Handle adding a new number item
  const handleAddNumberItem = () => {
    setNumberItems([...numberItems, {number: ''}]);
  };

  // Handle removing a number+qty item
  const handleRemoveNumberItem = (index: number) => {
    if (numberItems.length > 1) {
      setNumberItems(numberItems.filter((_, i) => i !== index));
    }
  };

  // Handle updating number field (force uppercase)
  const handleNumberChange = (index: number, value: string) => {
    const newItems = [...numberItems];
    newItems[index].number = value.toUpperCase();
    setNumberItems(newItems);
  };

  // 處理照片上傳
  const handlePhotoChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files) return;
    const files = Array.from(e.target.files);
    // 限制最多10張
    const newFiles = [...photos, ...files].slice(0, 10);
    setPhotos(newFiles);
  };

  // 移除單張照片
  const handleRemovePhoto = (idx: number) => {
    setPhotos(photos.filter((_, i) => i !== idx));
  };

  // Function to clear form fields
  const clearForm = () => {
    setNumberItems([{number: ''}]);
    setPalletQty('');
    setBarcode('');
    setPhotos([]);
    setWeight('');
    setChipQty('');
    setNoted('');
    setSoError('');
    setWeightError('');
    // SO, cargo, catalog, category, status, client — retained across entries
  };

  // Function to add product to temporary list
  const handleAddProduct = () => {
    let hasError = false;
    if (!soId) {
      setSoError('SO is required');
      hasError = true;
    } else {
      setSoError('');
    }
    if (weightError) {
      alert('Please fix the validation errors before adding the product');
      hasError = true;
    }
    if (hasError) return;

    const validItems = numberItems.filter(item => item.number.trim() !== '');
    const itemsToUse = validItems.length > 0 ? validItems : [{number: ''}];

    const newProducts: TempProduct[] = itemsToUse.map((item, idx) => ({
      id: `${Date.now()}-${idx}`,
      number: item.number,
      so_number_id: soId,
      so_number_str: soStr,
      so_vender: soVender,
      so_date: soDate,
      so_licence_number: soLicenceNumber,
      so_payload_number: soPayloadNumber,
      barcode,
      qty: palletQty,
      weight,
      chip_qty: chipQty,
      client,
      category,
      current_status,
      noted,
      photos,
      cargo: cargo || undefined,
      catalog: catalogId || undefined,
    }));

    setTempProducts([...tempProducts, ...newProducts]);
    clearForm();
  };

  // Function to remove a product from temporary list
  const handleRemoveProduct = (id: string) => {
    setTempProducts(tempProducts.filter(product => product.id !== id));
  };

  // Get category name by value
  const getCategoryName = (value: string) => {
    switch(value) {
      case '0': return 'Normal';
      case '1': return '大顆SSD';
      case '2': return 'Ram';
      case '3': return '小顆SSD';
      default: return 'Unknown';
    }
  };

  const getSSDCount = () => {
    return tempProducts.filter(product => 
      product.category === '1' || product.category === '3'
    ).length;
  };

  const getRAMCount = () => {
    return tempProducts.filter(product => 
      product.category === '2'
    ).length;
  };

  const initialState = { message: null, errors: {} };

  // Handle form submission
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (tempProducts.length === 0) {
      alert('Please add at least one product');
      return;
    }

    // Show confirmation dialog instead of window.confirm
    setShowConfirmDialog(true);
  };

  // New function to handle actual submission
  const handleConfirmedSubmit = async () => {
    setShowConfirmDialog(false);
    setIsSubmitting(true);

    try {
      // Create all products one by one
      const results = await Promise.all(
        tempProducts.map(async (product, idx) => {
          if (!product.so_number_id) {
            alert(`第 ${idx + 1} 筆產品 SO Number 不可為空`);
            throw new Error('SO Number is required');
          }
          const formData = new FormData();
          formData.append('so_number', product.so_number_id);
          if (product.barcode.trim()) formData.append('barcode', product.barcode);
          if (product.number.trim()) formData.append('number', product.number);
          if (product.qty.trim()) formData.append('qty', product.qty);
          if (product.chip_qty.trim()) formData.append('chip_qty', product.chip_qty);
          if (product.client.trim()) formData.append('client', product.client);
          if (product.category.trim()) formData.append('category', product.category);
          if (product.weight.trim()) formData.append('weight', product.weight);
          if (product.current_status.trim()) formData.append('current_status', product.current_status);
          if (product.noted.trim()) formData.append('noted', product.noted);
          if (product.cargo) formData.append('cargo', product.cargo);
          if (product.catalog) formData.append('catalog', product.catalog);
          product.photos.forEach((file) => formData.append('photos', file));

          return await createProduct(formData);
        })
      );
      if (results.every(result => result && result.success)) {
        router.push('/dashboard');
      } else {
        console.error('Failed to create product:', results);
        alert('Failed to create product. Please check the console for details.');
      }
    } catch (error) {
      console.error('An error occurred:', error);
      alert('An unexpected error occurred. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="max-w-full mx-auto">
      <form onSubmit={handleSubmit}>
        <div className="grid grid-cols-1 xl:grid-cols-2 gap-8">
          {/* Temporary Products List */}
          <div className="rounded-lg bg-white shadow-md p-2 md:p-3 border border-gray-100 xl:col-span-1 w-full">
            <div className="flex items-center justify-between space-x-3 mb-2">
              <div className="flex items-center space-x-2">
                <div className="bg-blue-100 p-1 rounded-lg">
                  <PlusIcon className="h-3 w-3 text-blue-600" />
                </div>
                <h1 className={`${lusitana.className} text-base font-bold text-gray-900`}>List</h1>
              </div>
              {tempProducts.length > 0 && (
                <button 
                  type="button" 
                  onClick={() => setTempProducts([])}
                  className="px-2 py-1 text-xs font-medium bg-red-50 text-red-600 rounded hover:bg-red-100 transition-colors"
                >
                  Clear All
                </button>
              )}
            </div>
            
            {tempProducts.length === 0 ? (
              <div className="text-center py-12 px-6 bg-gray-50 rounded-lg border border-dashed border-gray-300">
                <PlusIcon className="h-8 w-8 mx-auto text-gray-400 mb-4" />
                <p className="text-gray-500 mb-2">No products added yet</p>
                <p className="text-sm text-gray-400">Fill the form and click "Add" to begin creating products</p>
              </div>
            ) : (
              <div className="h-[500px] overflow-y-auto rounded border border-gray-200 shadow-inner">
                <table className="w-full text-xs text-left text-gray-500">
                  <thead className="text-xs text-gray-600 uppercase bg-gray-50 sticky top-0 z-10 shadow-sm font-medium">
                    <tr>
                      <th scope="col" className="px-1 py-2 whitespace-nowrap text-center w-6">Act</th>
                      <th scope="col" className="px-2 py-2 whitespace-nowrap">Barcode</th>
                      <th scope="col" className="px-2 py-2 whitespace-nowrap">SO Number</th>
                      <th scope="col" className="px-2 py-2 whitespace-nowrap">Number</th>
                      <th scope="col" className="px-2 py-2 whitespace-nowrap text-center">Pallet Qty</th>
                      <th scope="col" className="px-2 py-2 whitespace-nowrap text-center">Weight</th>
                      <th scope="col" className="px-2 py-2 whitespace-nowrap">Category</th>
                    </tr>
                  </thead>
                  <tbody>
                    {tempProducts.map((product) => (
                      <ExpandableRow
                        key={product.id}
                        product={product}
                        onRemove={handleRemoveProduct}
                        getCategoryName={getCategoryName}
                        onDetailClick={(product) => { setDetailProduct(product); setDetailDialogOpen(true); }}
                      />
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            
            {/* Replace the summary section */}
            {tempProducts.length > 0 && (
              <div className="mt-4 text-sm text-gray-600 bg-blue-50 p-3 rounded-md border border-blue-100">
                <div className="grid grid-cols-3 gap-4 text-center">
                  <div className="border-r border-blue-200">
                    <span className="block text-xs text-gray-500">Total</span>
                    <span className="font-semibold">{tempProducts.length}</span>
                  </div>
                  <div className="border-r border-blue-200">
                    <span className="block text-xs text-gray-500">SSD</span>
                    <span className="font-semibold">{getSSDCount()}</span>
                  </div>
                  <div>
                    <span className="block text-xs text-gray-500">RAM</span>
                    <span className="font-semibold">{getRAMCount()}</span>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Form Section */}
          <div className="rounded-lg bg-white shadow-md p-4 md:p-5 border border-gray-100 order-first xl:order-none xl:col-span-1 w-full max-w-none text-sm">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center space-x-3">
                <div className="bg-blue-100 p-2 rounded-lg">
                  <PencilSquareIcon className="h-4 w-4 text-blue-600" />
                </div>
                <h1 className={`${lusitana.className} text-lg font-bold text-gray-900`}>Add New Product</h1>
              </div>
              <button 
                type="button"
                onClick={handleAddProduct}
                className="flex items-center gap-2 px-4 py-2 rounded-md bg-green-500 hover:bg-green-600 text-white text-sm transition-colors"
              >
                <PlusIcon className="h-3 w-3" />
                <span>Add to List</span>
              </button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-x-4 gap-y-2 w-full">
              {/* Numbers + Qty Section - Multiple number+qty pairs */}
              <div className="mb-0 md:col-span-2 xl:col-span-3">
                <div className="flex items-center gap-3 mb-1">
                  <label className="text-sm font-bold text-gray-700">
                    Numbers
                  </label>
                  <button
                    type="button"
                    onClick={handleAddNumberItem}
                    className="flex items-center justify-center w-7 h-7 bg-white border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 hover:border-gray-400 transition-colors shadow-sm"
                  >
                    <PlusIcon className="h-4 w-4" />
                  </button>
                </div>
                <div className="p-2 bg-gray-50 rounded-lg border border-gray-200">
                  <div className="flex flex-wrap gap-3 items-center">
                    {numberItems.map((item, index) => (
                      <div key={index} className="flex items-center gap-1 bg-white px-2 py-1 rounded-md border border-gray-200">
                        <input
                          value={item.number}
                          onChange={(e) => handleNumberChange(index, e.target.value)}
                          className="w-28 rounded-md border border-gray-300 py-1.5 px-2 text-xs focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all bg-white"
                          placeholder="Number"
                        />
                        {numberItems.length > 1 && (
                          <button
                            type="button"
                            onClick={() => handleRemoveNumberItem(index)}
                            className="p-1 text-red-500 hover:text-red-700 transition-colors"
                          >
                            <XMarkIcon className="h-4 w-4" />
                          </button>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              {/* SO selector (Required) */}
              <div className="mb-0 md:col-span-2 xl:col-span-1">
                <AsyncSearchableSelect
                  value={soId}
                  onChange={(id) => { if (!id) handleSoSelectFull(null); }}
                  onSelectFull={handleSoSelectFull}
                  fetchOptions={fetchSOs}
                  minSearchLength={3}
                  label="SO Number"
                  placeholder="-- Select SO --"
                  className="text-xs"
                />
                {soError && <p className="mt-1 text-xs text-red-500">{soError}</p>}
              </div>

              {/* Date — read-only from SO */}
              <div className="mb-0">
                <label className="mb-1 block text-sm font-bold text-gray-700">Date</label>
                <input
                  readOnly
                  value={soDate}
                  className="block w-full rounded-md border border-gray-200 bg-gray-50 py-1.5 pl-3 text-xs text-gray-500 cursor-not-allowed"
                  placeholder="Auto from SO"
                />
              </div>

              {/* Vendor — read-only from SO */}
              <div className="mb-0">
                <label className="mb-1 block text-sm font-bold text-gray-700">Vendor</label>
                <input
                  readOnly
                  value={soVender}
                  className="block w-full rounded-md border border-gray-200 bg-gray-50 py-1.5 pl-3 text-xs text-gray-500 cursor-not-allowed"
                  placeholder="Auto from SO"
                />
              </div>

              {/* Barcode */}
              <div className="mb-0">
                <label htmlFor="barcode" className="mb-1 block text-sm font-bold text-gray-700">
                  Barcode
                </label>
                <input
                  id="barcode"
                  name="barcode"
                  value={barcode}
                  onChange={(e) => setBarcode(e.target.value)}
                  className="block w-full rounded-md border border-gray-300 py-1.5 pl-3 text-xs outline-2 placeholder:text-gray-500 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all"
                />
              </div>

              {/* Licence Number — read-only from SO */}
              <div className="mb-0">
                <label className="mb-1 block text-sm font-bold text-gray-700">Licence Number</label>
                <input
                  readOnly
                  value={soLicenceNumber}
                  className="block w-full rounded-md border border-gray-200 bg-gray-50 py-1.5 pl-3 text-xs text-gray-500 cursor-not-allowed"
                  placeholder="Auto from SO"
                />
              </div>

              {/* Payload Number — read-only from SO */}
              <div className="mb-0">
                <label className="mb-1 block text-sm font-bold text-gray-700">Payload Number</label>
                <input
                  readOnly
                  value={soPayloadNumber}
                  className="block w-full rounded-md border border-gray-200 bg-gray-50 py-1.5 pl-3 text-xs text-gray-500 cursor-not-allowed"
                  placeholder="Auto from SO"
                />
              </div>

              {/* Chip Qty */}
              <div className="mb-0">
                <label htmlFor="chip_qty" className="mb-1 block text-sm font-bold text-gray-700">
                  Chip Qty
                </label>
                <input
                  id="chip_qty"
                  name="chip_qty"
                  type="number"
                  min="0"
                  value={chipQty}
                  onChange={(e) => setChipQty(e.target.value)}
                  className="block w-full rounded-md border border-gray-300 py-1.5 pl-3 text-xs outline-2 placeholder:text-gray-500 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all"
                />
              </div>

              {/* Weight */}
              <div className="mb-0">
                <label htmlFor="weight" className="mb-1 block text-sm font-bold text-gray-700">
                  Weight
                </label>
                <input
                  id="weight"
                  name="weight"
                  value={weight}
                  onChange={handleWeightChange}
                  className="block w-full rounded-md border border-gray-300 py-1.5 pl-3 text-xs outline-2 placeholder:text-gray-500 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all"
                />
                {weightError && <p className="mt-1 text-xs text-red-500">{weightError}</p>}
              </div>

              {/* Pallet Qty */}
              <div className="mb-0">
                <label htmlFor="palletQty" className="mb-1 block text-sm font-bold text-gray-700">
                  Pallet Qty
                </label>
                <input
                  id="palletQty"
                  name="palletQty"
                  type="text"
                  value={palletQty}
                  onChange={(e) => {
                    const v = e.target.value;
                    if (v === '' || /^\d+$/.test(v)) {
                      setPalletQty(v.replace(/^0+/, '') || (v === '' ? '' : '0'));
                    }
                  }}
                  className="block w-full rounded-md border border-gray-300 py-1.5 pl-3 text-xs outline-2 placeholder:text-gray-500 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all"
                  placeholder="0"
                />
              </div>

              {/* Client */}
              <div className="mb-0">
                <label htmlFor="client" className="mb-1 block text-sm font-bold text-gray-700">
                  Client
                </label>
                <div className="relative">
                  <input
                    id="client"
                    name="client"
                    value={client}
                    onChange={handleClientChange}
                    className="peer block w-full rounded-md border border-gray-300 py-1.5 pl-8 text-xs outline-2 placeholder:text-gray-500 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all"
                   
                  />
                  
                </div>
              </div>

              {/* status */}
              <div className="mb-0">
              <label htmlFor="current_status" className="mb-1 block text-sm font-bold text-gray-700">
                Status
              </label>
              <select
                id="current_status"
                name="current_status"
                value={current_status}
                onChange={e => setCurrentStatus(e.target.value)}
                className="block w-full rounded-md border border-gray-300 py-1.5 pl-8 text-xs outline-2 placeholder:text-gray-500 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all"
              >
                <option value="0">0: 入庫</option>
                <option value="1">1: 出貨</option>
              </select>
              </div>

              {/* Cargo */}
              <div className="mb-0">
                <SearchableSelect
                  options={cargos}
                  value={cargo}
                  onChange={setCargo}
                  label="Cargo"
                  placeholder="-- Select Cargo --"
                  className="text-xs"
                />
              </div>

              {/* Catalog */}
              <div className="mb-0">
                <SearchableSelect
                  options={catalogs}
                  value={catalogId}
                  onChange={setCatalogId}
                  label="Catalog"
                  placeholder="-- Select Catalog --"
                  className="text-xs"
                />
              </div>

              {/* Category */}
              <div className="mb-0">
                <label htmlFor="category" className="mb-1 block text-sm font-bold text-gray-700">
                  Category
                </label>
                <div className="relative">
                  <select
                    id="category"
                    name="category"
                    value={category}
                    onChange={(e) => setCategory(e.target.value)}
                    className="peer block w-full rounded-md border border-gray-300 py-1.5 pl-8 text-xs outline-2 placeholder:text-gray-500 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all"
                  >
                    <option value="0"> 0: Normal</option>
                    <option value="1"> 1: 大顆SSD</option>
                    <option value="2"> 2: Ram</option>
                    <option value="3"> 3: 小顆SSD </option>
                  </select>
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-500">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9.568 3H5.25A2.25 2.25 0 0 0 3 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 0 0 5.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 0 0 9.568 3Z" />
                    <path strokeLinecap="round" strokeLinejoin="round" d="M6 6h.008v.008H6V6Z" />
                  </svg>
                </div>
              </div>

              {/* note */}
              <div className="mb-0 xl:col-span-2">
                <label htmlFor="noted" className="mb-1 block text-sm font-bold text-gray-700">
                  Note
                </label>
                <input
                  type="text"
                  id="noted"
                  name="noted"
                  value={noted}
                  onChange={e => setNoted(e.target.value)}
                  className="block w-full rounded-md border border-gray-300 py-1.5 px-3 text-xs outline-2 placeholder:text-gray-500 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all"
                
                />
              </div>

              {/* 新增照片上傳 */}
              <div className="mb-0 md:col-span-2 xl:col-span-3">
                <label className="mb-1 block text-sm font-bold text-gray-700">
                  Photos (最多10張)
                </label>
                <input
                  type="file"
                  accept="image/*"
                  multiple
                  onChange={handlePhotoChange}
                  disabled={photos.length >= 10}
                  className="block w-full rounded-md border border-gray-300 py-1 px-2 text-xs"
                />
                <div className="flex flex-wrap gap-2 mt-2">
                  {photos.map((file, idx) => (
                    <div key={idx} className="relative group">
                      <img
                        src={URL.createObjectURL(file)}
                        alt={`preview-${idx}`}
                        className="w-10 h-10 object-cover rounded border"
                      />
                      <button
                        type="button"
                        onClick={() => handleRemovePhoto(idx)}
                        className="absolute top-0 right-0 bg-red-500 text-white rounded-full w-4 h-4 flex items-center justify-center text-xs opacity-80 hover:opacity-100"
                        title="移除"
                      >×</button>
                    </div>
                  ))}
                </div>
                {photos.length >= 10 && (
                  <p className="text-xs text-red-500 mt-1">最多只能上傳10張圖片</p>
                )}
              </div>
            </div>
          </div>
        </div>
        
        {/* Action buttons */}
        <div className="mt-10 flex flex-col sm:flex-row sm:justify-end gap-4">
          <Link
            href="/dashboard"
            className="flex h-10 sm:h-12 items-center justify-center rounded-lg bg-gray-100 px-8 text-base font-medium text-gray-600 transition-colors hover:bg-gray-200"
          >
            Back to Dashboard
          </Link>
          
          <Button 
            type="submit" 
            className={`flex h-10 sm:h-12 items-center justify-center gap-2 px-8 text-base font-medium transition-all duration-200 ${
              isSubmitting || tempProducts.length === 0
                ? 'bg-gray-400 cursor-not-allowed'
                : 'bg-blue-600 hover:bg-blue-700'
            }`}
            disabled={isSubmitting || tempProducts.length === 0}
          >
            {isSubmitting ? (
              <>
                <svg className="animate-spin h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                <span>Processing...</span>
              </>
            ) : tempProducts.length > 0 ? (
              <>
                <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" />
                </svg>
                <span>Create {tempProducts.length} Product{tempProducts.length !== 1 ? 's' : ''}</span>
              </>
            ) : (
              <span>Add Products to Continue</span>
            )}
          </Button>
        </div>
      </form>

      {/* Add Confirmation Dialog */}
      <Dialog
        isOpen={showConfirmDialog}
        onClose={() => setShowConfirmDialog(false)}
        onConfirm={handleConfirmedSubmit}
        title="確認創建產品"
      >
        <div className="space-y-4">
          <p className="text-gray-500">
            您確定要創建以下產品嗎？
          </p>
          <div className="bg-gray-50 p-4 rounded-lg space-y-2">
            <div className="flex justify-between">
              <span className="text-gray-600">總數：</span>
              <span className="font-medium">{tempProducts.length}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">SSD：</span>
              <span className="font-medium">{getSSDCount()}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">RAM：</span>
              <span className="font-medium">{getRAMCount()}</span>
            </div>
          </div>
        </div>
      </Dialog>

      {/* Detail Dialog */}
      {detailDialogOpen && detailProduct && (
        <Dialog
          isOpen={detailDialogOpen}
          onClose={() => setDetailDialogOpen(false)}
          onConfirm={() => setDetailDialogOpen(false)}
          title="產品詳細資料"
        >
          <div className="space-y-2 text-sm text-gray-700">
            <div><span className="font-semibold">SO:</span> {detailProduct.so_number_str}</div>
            <div><span className="font-semibold">Date:</span> {detailProduct.so_date || '-'}</div>
            <div><span className="font-semibold">Vendor:</span> {detailProduct.so_vender || '-'}</div>
            <div><span className="font-semibold">Barcode:</span> {detailProduct.barcode || '-'}</div>
            <div><span className="font-semibold">Number:</span> {detailProduct.number || '-'}</div>
            <div><span className="font-semibold">Licence:</span> {detailProduct.so_licence_number || '-'}</div>
            <div><span className="font-semibold">Payload:</span> {detailProduct.so_payload_number || '-'}</div>
            <div><span className="font-semibold">Qty:</span> {detailProduct.qty || '0'}</div>
            <div><span className="font-semibold">Chip Qty:</span> {detailProduct.chip_qty || '0'}</div>
            <div><span className="font-semibold">Category:</span> {getCategoryName(detailProduct.category)}</div>
            <div><span className="font-semibold">Client:</span> {detailProduct.client || '-'}</div>
            <div><span className="font-semibold">Photos:</span> {detailProduct.photos.length > 0 ? `${detailProduct.photos.length} 張` : '無'}</div>
            {detailProduct.photos.length > 0 && (
              <div className="flex flex-wrap gap-2 mt-2">
                {detailProduct.photos.map((file, idx) => (
                  <img key={idx} src={URL.createObjectURL(file)} alt={`preview-${idx}`} className="w-14 h-14 object-cover rounded border" />
                ))}
              </div>
            )}
          </div>
        </Dialog>
      )}
    </div>
  );
}

// 在檔案底部新增 ExpandableRow 元件
function ExpandableRow({ product, onRemove, getCategoryName, onDetailClick }: { product: TempProduct, onRemove: (id: string) => void, getCategoryName: (v: string) => string, onDetailClick: (product: TempProduct) => void }) {
  return (
    <tr className="bg-white border-b hover:bg-gray-50 cursor-pointer text-xs h-8" onClick={() => onDetailClick(product)}>
      <td className="px-1 py-1 text-center w-6" onClick={e => { e.stopPropagation(); onRemove(product.id); }}>
        <button
          type="button"
          className="p-0.5 text-red-500 hover:text-red-700 rounded hover:bg-red-50 transition-colors"
          title="Remove product"
        >
          <svg className="h-3 w-3" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
        </button>
      </td>
      <td className="px-2 py-1 truncate text-gray-700 font-semibold max-w-[100px]">{product.barcode || '-'}</td>
      <td className="px-2 py-1 truncate text-gray-900 font-semibold max-w-[120px]">{product.so_number_str}</td>
      <td className="px-2 py-1 truncate text-gray-700 font-semibold max-w-[80px]">{product.number || '-'}</td>
      <td className="px-2 py-1 text-center text-gray-700 font-semibold">{product.qty || '0'}</td>
      <td className="px-2 py-1 text-center text-gray-700 font-semibold">{product.weight || '0'}</td>
      <td className="px-2 py-1 truncate text-gray-700 max-w-[80px]">
        <span className={`inline-block px-2 py-0.5 rounded text-xs font-semibold ${
          product.category === '1' ? 'bg-blue-100 text-blue-700' :
          product.category === '2' ? 'bg-green-100 text-green-700' :
          product.category === '3' ? 'bg-purple-100 text-purple-700' :
          'bg-gray-100 text-gray-700'
        }`}>
          {getCategoryName(product.category)}
        </span>
      </td>
    </tr>
  );
}
