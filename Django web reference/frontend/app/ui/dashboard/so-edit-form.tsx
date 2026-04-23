"use client"

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { SO } from '@/interface/IDatatable';

const API_URL = process.env.NEXT_PUBLIC_Django_API_URL;

function getAuthHeaders(): HeadersInit {
  return {
    'Content-Type': 'application/json',
    'X-API-Key': process.env.NEXT_PUBLIC_API_KEY || '',
  };
}

export default function SOEditForm({ so }: { so: SO }) {
  const router = useRouter();
  const [formData, setFormData] = useState({
    so_number: so.so_number ?? '',
    vender: so.vender ?? '',
    date: so.date ?? '',
    payload_number: so.payload_number ?? '',
    licence_number: so.licence_number ?? '',
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitting, setSubmitting] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    if (errors[name]) {
      setErrors((prev) => { const next = { ...prev }; delete next[name]; return next; });
    }
  };

  const validate = () => {
    const newErrors: Record<string, string> = {};
    if (!formData.so_number.trim()) newErrors.so_number = 'SO Number is required';
    if (!formData.date) newErrors.date = 'Date is required';
    if (formData.vender.length > 10) newErrors.vender = 'Vender must be 10 characters or less';
    return newErrors;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const validationErrors = validate();
    if (Object.keys(validationErrors).length > 0) {
      setErrors(validationErrors);
      return;
    }

    setSubmitting(true);
    try {
      const res = await fetch(`${API_URL}/product/sos/${so.id}/`, {
        method: 'PUT',
        headers: getAuthHeaders(),
        body: JSON.stringify({
          so_number: formData.so_number.trim(),
          vender: formData.vender.trim(),
          date: formData.date,
          payload_number: formData.payload_number.trim() || null,
          licence_number: formData.licence_number.trim() || null,
        }),
      });

      if (res.ok) {
        router.push('/dashboard/so');
        router.refresh();
      } else {
        const errData = await res.json();
        const fieldErrors: Record<string, string> = {};
        for (const [k, v] of Object.entries(errData)) {
          fieldErrors[k] = Array.isArray(v) ? (v as string[]).join(', ') : String(v);
        }
        setErrors(fieldErrors);
      }
    } catch {
      setErrors({ general: 'Failed to update SO. Please try again.' });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="rounded-lg bg-white p-6 shadow-sm ring-1 ring-gray-100 max-w-xl">
      <div className="mb-5 grid gap-4">
        {/* SO Number */}
        <div>
          <label htmlFor="so_number" className="mb-1 block text-sm font-bold text-gray-700">
            SO Number <span className="text-red-500">*</span>
          </label>
          <input
            id="so_number"
            name="so_number"
            type="text"
            value={formData.so_number}
            onChange={handleChange}
            className={`block w-full rounded-md border py-2 pl-3 text-sm outline-2 placeholder:text-gray-400 focus:ring-1 transition-all ${
              errors.so_number
                ? 'border-red-500 focus:border-red-500 focus:ring-red-500'
                : 'border-gray-300 focus:border-blue-500 focus:ring-blue-500'
            }`}
          />
          {errors.so_number && <p className="mt-1 text-xs text-red-500">{errors.so_number}</p>}
        </div>

        {/* Vender */}
        <div>
          <label htmlFor="vender" className="mb-1 block text-sm font-bold text-gray-700">
            Vender
          </label>
          <input
            id="vender"
            name="vender"
            type="text"
            maxLength={10}
            value={formData.vender}
            onChange={handleChange}
            className={`block w-full rounded-md border py-2 pl-3 text-sm outline-2 placeholder:text-gray-400 focus:ring-1 transition-all ${
              errors.vender
                ? 'border-red-500 focus:border-red-500 focus:ring-red-500'
                : 'border-gray-300 focus:border-blue-500 focus:ring-blue-500'
            }`}
          />
          {errors.vender && <p className="mt-1 text-xs text-red-500">{errors.vender}</p>}
        </div>

        {/* Date */}
        <div>
          <label htmlFor="date" className="mb-1 block text-sm font-bold text-gray-700">
            Date <span className="text-red-500">*</span>
          </label>
          <input
            id="date"
            name="date"
            type="date"
            value={formData.date}
            onChange={handleChange}
            className={`block w-full rounded-md border py-2 pl-3 text-sm outline-2 focus:ring-1 transition-all ${
              errors.date
                ? 'border-red-500 focus:border-red-500 focus:ring-red-500'
                : 'border-gray-300 focus:border-blue-500 focus:ring-blue-500'
            }`}
          />
          {errors.date && <p className="mt-1 text-xs text-red-500">{errors.date}</p>}
        </div>

        {/* Payload Number */}
        <div>
          <label htmlFor="payload_number" className="mb-1 block text-sm font-bold text-gray-700">
            Payload Number
          </label>
          <input
            id="payload_number"
            name="payload_number"
            type="text"
            value={formData.payload_number}
            onChange={handleChange}
            className="block w-full rounded-md border border-gray-300 py-2 pl-3 text-sm outline-2 placeholder:text-gray-400 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all"
          />
        </div>

        {/* Licence Number */}
        <div>
          <label htmlFor="licence_number" className="mb-1 block text-sm font-bold text-gray-700">
            Licence Number
          </label>
          <input
            id="licence_number"
            name="licence_number"
            type="text"
            value={formData.licence_number}
            onChange={handleChange}
            className="block w-full rounded-md border border-gray-300 py-2 pl-3 text-sm outline-2 placeholder:text-gray-400 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all"
          />
        </div>

      </div>

      {errors.general && (
        <p className="mb-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-600">{errors.general}</p>
      )}

      <div className="flex items-center gap-3">
        <button
          type="submit"
          disabled={submitting}
          className="rounded-md bg-blue-600 px-5 py-2 text-sm font-semibold text-white hover:bg-blue-700 disabled:opacity-50 transition-colors"
        >
          {submitting ? 'Saving...' : 'Save Changes'}
        </button>
        <Link
          href="/dashboard/so"
          className="rounded-md border border-gray-300 px-5 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-50 transition-colors"
        >
          Cancel
        </Link>
      </div>
    </form>
  );
}
