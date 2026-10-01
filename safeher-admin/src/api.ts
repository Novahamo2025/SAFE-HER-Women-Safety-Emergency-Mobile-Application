import axios from 'axios';

export interface ApiResponse<T> {
  success: boolean;
  message: string;
  data: T;
}

export interface AdminSession {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  userId: number;
  name: string;
  email: string;
  phone: string;
  role: string;
}

export interface DashboardStats {
  activeSosCount: number;
  activeJourneysCount: number;
  pendingCheckinsCount: number;
  totalUsersCount: number;
  failedDeliveriesCount: number;
}

export interface Emergency {
  id: number;
  userName: string;
  userPhone: string;
  eventType: string;
  status: string;
  startedAt: string;
  latitude: number | null;
  longitude: number | null;
  locationRecordedAt: string | null;
}

export interface Journey {
  id: number;
  userName: string;
  userPhone: string;
  destination: string;
  startLat: number | null;
  startLng: number | null;
  destLat: number | null;
  destLng: number | null;
  expectedArrival: string;
  gracePeriodMinutes: number;
  status: string;
  startedAt: string;
  completedAt: string | null;
}

export interface CheckIn {
  id: number;
  userName: string;
  userPhone: string;
  scheduledTime: string;
  gracePeriodMinutes: number;
  status: string;
  lastPromptedAt: string | null;
  completedAt: string | null;
}

export interface EmergencyContact {
  id: number;
  userName: string;
  userPhone: string;
  contactName: string;
  phone: string;
  relationship: string | null;
  priority: number;
  notifySms: boolean;
  notifyPush: boolean;
  verified: boolean;
  createdAt: string;
}

export interface Delivery {
  id: number;
  emergencyEventId: number | null;
  recipientPhone: string;
  channel: string;
  status: string;
  providerRef: string | null;
  errorMessage: string | null;
  sentAt: string;
}

export interface AdminUser {
  id: number;
  name: string;
  email: string;
  phone: string;
  role: string;
  verified: boolean;
  accountStatus: string;
  lastLoginAt: string | null;
  createdAt: string;
}

export interface DashboardData {
  stats: DashboardStats;
  emergencies: Emergency[];
  journeys: Journey[];
  checkins: CheckIn[];
  contacts: EmergencyContact[];
  deliveries: Delivery[];
  users: AdminUser[];
}

const api = axios.create({ baseURL: '/api' });

api.interceptors.request.use((config) => {
  const token = sessionStorage.getItem('safeher-admin-token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

export async function signIn(identifier: string, password: string) {
  const response = await api.post<ApiResponse<AdminSession>>('/auth/login', {
    identifier,
    password,
  });
  return response.data.data;
}

export async function getDashboardData(): Promise<DashboardData> {
  const [stats, emergencies, journeys, checkins, contacts, deliveries, users] = await Promise.all([
    api.get<ApiResponse<DashboardStats>>('/admin/stats'),
    api.get<ApiResponse<Emergency[]>>('/admin/emergencies'),
    api.get<ApiResponse<Journey[]>>('/admin/journeys'),
    api.get<ApiResponse<CheckIn[]>>('/admin/checkins'),
    api.get<ApiResponse<EmergencyContact[]>>('/admin/contacts'),
    api.get<ApiResponse<Delivery[]>>('/admin/deliveries'),
    api.get<ApiResponse<AdminUser[]>>('/admin/users'),
  ]);

  return {
    stats: stats.data.data,
    emergencies: emergencies.data.data,
    journeys: journeys.data.data,
    checkins: checkins.data.data,
    contacts: contacts.data.data,
    deliveries: deliveries.data.data,
    users: users.data.data,
  };
}

export function getApiErrorMessage(error: unknown) {
  if (axios.isAxiosError<{ message?: string }>(error)) {
    return error.response?.data?.message ?? 'Could not reach the SafeHer backend.';
  }
  return error instanceof Error ? error.message : 'Something went wrong.';
}