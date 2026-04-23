import {
  Vendor, SO, SODetail, SOPhoto, Pallet, Board, ChipBrand, Chip,
  PaginatedResult, DashboardStats,
} from '@/interface/IDatatable';

const API = process.env.NEXT_PUBLIC_Django_API_URL || 'http://localhost:8000';
const PREFIX = `${API}/product`;

async function apiFetch(path: string, options: RequestInit = {}): Promise<Response> {
  const { getServerSession } = await import('next-auth');
  const { authOptions } = await import('@/app/api/auth/[...nextauth]/route');
  const session = await getServerSession(authOptions);
  const token = (session as any)?.accessToken;
  return fetch(`${PREFIX}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Token ${token}` } : {}),
      ...(options.headers || {}),
    },
  });
}

// ─────────────────────────────────────────────────────── Vendors
export async function fetchVendors(): Promise<Vendor[]> {
  const res = await apiFetch('/vendors/');
  if (!res.ok) throw new Error('Failed to fetch vendors');
  return res.json();
}

export async function createVendor(data: Partial<Vendor>): Promise<Vendor> {
  const res = await apiFetch('/vendors/', { method: 'POST', body: JSON.stringify(data) });
  if (!res.ok) throw new Error('Failed to create vendor');
  return res.json();
}

export async function updateVendor(id: number, data: Partial<Vendor>): Promise<Vendor> {
  const res = await apiFetch(`/vendors/${id}/`, { method: 'PUT', body: JSON.stringify(data) });
  if (!res.ok) throw new Error('Failed to update vendor');
  return res.json();
}

export async function deleteVendor(id: number): Promise<void> {
  const res = await apiFetch(`/vendors/${id}/`, { method: 'DELETE' });
  if (!res.ok) throw new Error('Failed to delete vendor');
}

// ─────────────────────────────────────────────────────── SOs
export async function fetchSOs(params: {
  q?: string; vendor?: string; date_from?: string; date_to?: string;
  page?: number; page_size?: number;
} = {}): Promise<PaginatedResult<SO>> {
  const qs = new URLSearchParams();
  if (params.q)          qs.set('q', params.q);
  if (params.vendor)     qs.set('vendor', params.vendor);
  if (params.date_from)  qs.set('date_from', params.date_from);
  if (params.date_to)    qs.set('date_to', params.date_to);
  if (params.page)       qs.set('page', String(params.page));
  if (params.page_size)  qs.set('page_size', String(params.page_size));
  const res = await apiFetch(`/sos/?${qs}`);
  if (!res.ok) throw new Error('Failed to fetch SOs');
  return res.json();
}

export async function fetchSO(id: number): Promise<SODetail> {
  const res = await apiFetch(`/sos/${id}/`);
  if (!res.ok) throw new Error('Failed to fetch SO');
  return res.json();
}

export async function createSO(data: Partial<SO>): Promise<SO> {
  const res = await apiFetch('/sos/', { method: 'POST', body: JSON.stringify(data) });
  if (!res.ok) throw new Error('Failed to create SO');
  return res.json();
}

export async function updateSO(id: number, data: Partial<SO>): Promise<SO> {
  const res = await apiFetch(`/sos/${id}/`, { method: 'PUT', body: JSON.stringify(data) });
  if (!res.ok) throw new Error('Failed to update SO');
  return res.json();
}

// ─────────────────────────────────────────────────────── Pallets
export async function fetchPallets(soId: number): Promise<Pallet[]> {
  const res = await apiFetch(`/sos/${soId}/pallets/`);
  if (!res.ok) throw new Error('Failed to fetch pallets');
  return res.json();
}

export async function createPallet(soId: number, data: Partial<Pallet>): Promise<Pallet> {
  const res = await apiFetch(`/sos/${soId}/pallets/`, { method: 'POST', body: JSON.stringify(data) });
  if (!res.ok) throw new Error('Failed to create pallet');
  return res.json();
}

export async function updatePallet(soId: number, id: number, data: Partial<Pallet>): Promise<Pallet> {
  const res = await apiFetch(`/sos/${soId}/pallets/${id}/`, { method: 'PUT', body: JSON.stringify(data) });
  if (!res.ok) throw new Error('Failed to update pallet');
  return res.json();
}

export async function deletePallet(soId: number, id: number): Promise<void> {
  const res = await apiFetch(`/sos/${soId}/pallets/${id}/`, { method: 'DELETE' });
  if (!res.ok) throw new Error('Failed to delete pallet');
}

// ─────────────────────────────────────────────────────── Boards
export async function fetchBoards(soId: number, params: {
  date_from?: string; date_to?: string; page?: number; page_size?: number;
} = {}): Promise<PaginatedResult<Board>> {
  const qs = new URLSearchParams();
  if (params.date_from) qs.set('date_from', params.date_from);
  if (params.date_to)   qs.set('date_to', params.date_to);
  if (params.page)      qs.set('page', String(params.page));
  if (params.page_size) qs.set('page_size', String(params.page_size));
  const res = await apiFetch(`/sos/${soId}/boards/?${qs}`);
  if (!res.ok) throw new Error('Failed to fetch boards');
  return res.json();
}

export async function fetchBoard(id: number): Promise<Board> {
  const res = await apiFetch(`/boards/${id}/`);
  if (!res.ok) throw new Error('Failed to fetch board');
  return res.json();
}

export async function updateBoard(id: number, data: Partial<Board>): Promise<Board> {
  const res = await apiFetch(`/boards/${id}/`, { method: 'PUT', body: JSON.stringify(data) });
  if (!res.ok) throw new Error('Failed to update board');
  return res.json();
}

export async function deleteBoard(id: number): Promise<void> {
  const res = await apiFetch(`/boards/${id}/`, { method: 'DELETE' });
  if (!res.ok) throw new Error('Failed to delete board');
}

// ─────────────────────────────────────────────────────── Chips
export async function createChip(boardId: number, data: Partial<Chip>): Promise<Chip> {
  const res = await apiFetch(`/boards/${boardId}/chips/`, { method: 'POST', body: JSON.stringify(data) });
  if (!res.ok) throw new Error('Failed to create chip');
  return res.json();
}

export async function updateChip(boardId: number, id: number, data: Partial<Chip>): Promise<Chip> {
  const res = await apiFetch(`/boards/${boardId}/chips/${id}/`, { method: 'PUT', body: JSON.stringify(data) });
  if (!res.ok) throw new Error('Failed to update chip');
  return res.json();
}

export async function deleteChip(boardId: number, id: number): Promise<void> {
  const res = await apiFetch(`/boards/${boardId}/chips/${id}/`, { method: 'DELETE' });
  if (!res.ok) throw new Error('Failed to delete chip');
}

// ─────────────────────────────────────────────────────── ChipBrands
export async function fetchChipBrands(): Promise<ChipBrand[]> {
  const res = await apiFetch('/chipbrands/');
  if (!res.ok) throw new Error('Failed to fetch chip brands');
  return res.json();
}

export async function createChipBrand(data: Partial<ChipBrand>): Promise<ChipBrand> {
  const res = await apiFetch('/chipbrands/', { method: 'POST', body: JSON.stringify(data) });
  if (!res.ok) throw new Error('Failed to create chip brand');
  return res.json();
}

export async function updateChipBrand(id: number, data: Partial<ChipBrand>): Promise<ChipBrand> {
  const res = await apiFetch(`/chipbrands/${id}/`, { method: 'PUT', body: JSON.stringify(data) });
  if (!res.ok) throw new Error('Failed to update chip brand');
  return res.json();
}

export async function deleteChipBrand(id: number): Promise<void> {
  const res = await apiFetch(`/chipbrands/${id}/`, { method: 'DELETE' });
  if (!res.ok) throw new Error('Failed to delete chip brand');
}

// ─────────────────────────────────────────────────────── Dashboard
export async function fetchDashboardStats(): Promise<DashboardStats> {
  const res = await apiFetch('/dashboard/');
  if (!res.ok) throw new Error('Failed to fetch dashboard stats');
  return res.json();
}
