import { FormEvent, Fragment, ReactNode, useEffect, useState } from 'react';
import axios from 'axios';
import {
  Activity,
  AlertTriangle,
  BookUser,
  CheckCircle2,
  Clock3,
  LogOut,
  MapPin,
  RefreshCw,
  Send,
  Shield,
  Users,
} from 'lucide-react';
import {
  AdminSession,
  AdminUser,
  CheckIn,
  DashboardData,
  Delivery,
  Emergency,
  EmergencyContact,
  getApiErrorMessage,
  getDashboardData,
  Journey,
  signIn,
} from './api';

type View = 'overview' | 'emergencies' | 'journeys' | 'checkins' | 'contacts' | 'deliveries' | 'users';

const sessionTokenKey = 'safeher-admin-token';
const emptyDashboard: DashboardData = {
  stats: {
    activeSosCount: 0,
    activeJourneysCount: 0,
    pendingCheckinsCount: 0,
    totalUsersCount: 0,
    failedDeliveriesCount: 0,
  },
  emergencies: [],
  journeys: [],
  checkins: [],
  contacts: [],
  deliveries: [],
  users: [],
};

const navItems: { id: View; label: string; icon: typeof Activity }[] = [
  { id: 'overview', label: 'Overview', icon: Activity },
  { id: 'emergencies', label: 'Active SOS', icon: AlertTriangle },
  { id: 'journeys', label: 'Safe walks', icon: MapPin },
  { id: 'checkins', label: 'Check-ins', icon: Clock3 },
  { id: 'contacts', label: 'Contacts', icon: BookUser },
  { id: 'deliveries', label: 'Alerts', icon: Send },
  { id: 'users', label: 'Users', icon: Users },
];

function readStoredSession(): AdminSession | null {
  const accessToken = sessionStorage.getItem(sessionTokenKey);
  if (!accessToken) return null;
  return {
    accessToken,
    refreshToken: '',
    tokenType: 'Bearer',
    userId: 0,
    name: sessionStorage.getItem('safeher-admin-name') ?? 'Admin',
    email: sessionStorage.getItem('safeher-admin-email') ?? '',
    phone: '',
    role: 'ROLE_ADMIN',
  };
}

function formatDate(value?: string | null) {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? '—'
    : new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(date);
}

function statusClass(status: string) {
  return `status-pill status-${replaceUnderscores(status.toLowerCase(), '-')}`;
}

function replaceUnderscores(value: string, replacement: string) {
  return value.split('_').join(replacement);
}

function Status({ value }: Readonly<{ value: string }>) {
  return <span className={statusClass(value)}>{replaceUnderscores(value, ' ')}</span>;
}

function DataTable<T extends { id: number }>({
  columns,
  rows,
  empty,
  renderRow,
}: Readonly<{
  columns: readonly string[];
  rows: readonly T[];
  empty: string;
  renderRow: (row: T) => ReactNode;
}>) {
  return (
    <div className="table-scroll">
      <table>
        <thead>
          <tr>{columns.map((column) => <th key={column}>{column}</th>)}</tr>
        </thead>
        <tbody>
          {rows.length === 0 ? (
            <tr><td className="empty-cell" colSpan={columns.length}>{empty}</td></tr>
          ) : rows.map((row) => <Fragment key={row.id}>{renderRow(row)}</Fragment>)}
        </tbody>
      </table>
    </div>
  );
}

function Panel({ title, detail, children }: Readonly<{ title: string; detail?: string; children: ReactNode }>) {
  return (
    <section className="panel">
      <div className="panel-heading">
        <div>
          <h2>{title}</h2>
          {detail && <p>{detail}</p>}
        </div>
      </div>
      {children}
    </section>
  );
}

function Login({ onLogin }: Readonly<{ onLogin: (session: AdminSession) => void }>) {
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError('');
    try {
      const session = await signIn(identifier.trim(), password);
      if (session.role !== 'ROLE_ADMIN') {
        throw new Error('This account does not have administrator access.');
      }
      onLogin(session);
    } catch (loginError) {
      setError(getApiErrorMessage(loginError));
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="login-page">
      <section className="login-panel">
        <div className="brand-mark"><Shield size={24} /></div>
        <p className="eyebrow">SAFEHER OPERATIONS</p>
        <h1>Admin sign in</h1>
        <p className="login-copy">Sign in with an administrator account to view live safety activity.</p>
        <form onSubmit={submit} className="login-form">
          <label htmlFor="identifier">Email or phone</label>
          <input
            id="identifier"
            autoComplete="username"
            value={identifier}
            onChange={(event) => setIdentifier(event.target.value)}
            required
          />
          <label htmlFor="password">Password</label>
          <input
            id="password"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            required
          />
          {error && <p className="form-error" role="alert">{error}</p>}
          <button className="primary-button login-submit" type="submit" disabled={busy}>
            {busy ? 'Signing in…' : 'Sign in'}
          </button>
        </form>
        <p className="login-footnote">Administrator access is verified by the SafeHer API.</p>
      </section>
    </main>
  );
}

export default function AdminDashboard() {
  const [session, setSession] = useState<AdminSession | null>(readStoredSession);
  const [view, setView] = useState<View>('overview');
  const [dashboard, setDashboard] = useState<DashboardData | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);
  const [updatedAt, setUpdatedAt] = useState<Date | null>(null);

  useEffect(() => {
    if (!session) return;
    let disposed = false;

    async function refresh() {
      setLoading((current) => dashboard === null || current);
      try {
        const nextDashboard = await getDashboardData();
        if (disposed) return;
        setDashboard(nextDashboard);
        setError('');
        setUpdatedAt(new Date());
      } catch (requestError) {
        if (disposed) return;
        if (axios.isAxiosError(requestError) && [401, 403].includes(requestError.response?.status ?? 0)) {
          sessionStorage.removeItem(sessionTokenKey);
          sessionStorage.removeItem('safeher-admin-name');
          sessionStorage.removeItem('safeher-admin-email');
          setSession(null);
          setError(requestError.response?.status === 403
            ? 'This account does not have administrator access.'
            : 'Your session expired. Sign in again.');
        } else {
          setError(getApiErrorMessage(requestError));
        }
      } finally {
        if (!disposed) setLoading(false);
      }
    }

    void refresh();
    const interval = window.setInterval(() => void refresh(), 15000);
    return () => {
      disposed = true;
      window.clearInterval(interval);
    };
  }, [session, refreshKey]);

  function handleLogin(nextSession: AdminSession) {
    sessionStorage.setItem(sessionTokenKey, nextSession.accessToken);
    sessionStorage.setItem('safeher-admin-name', nextSession.name);
    sessionStorage.setItem('safeher-admin-email', nextSession.email);
    setDashboard(null);
    setSession(nextSession);
  }

  function signOut() {
    sessionStorage.removeItem(sessionTokenKey);
    sessionStorage.removeItem('safeher-admin-name');
    sessionStorage.removeItem('safeher-admin-email');
    setSession(null);
    setDashboard(null);
    setError('');
  }

  if (!session) return <Login onLogin={handleLogin} />;

  const data = dashboard ?? emptyDashboard;
  const deliveredCount = data.deliveries.filter((delivery) => delivery.status === 'DELIVERED').length;
  const deliveryRate = data.deliveries.length
    ? `${Math.round((deliveredCount / data.deliveries.length) * 100)}%`
    : '—';
  const activeView = navItems.find((item) => item.id === view);
  const ViewIcon = activeView?.icon ?? Activity;

  return (
    <div className="dashboard-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark"><Shield size={21} /></div>
          <div><strong>SafeHer</strong><span>Operations command</span></div>
        </div>
        <nav className="side-nav" aria-label="Dashboard sections">
          {navItems.map(({ id, label, icon: Icon }) => (
            <button key={id} className={`nav-item ${view === id ? 'selected' : ''}`} onClick={() => setView(id)}>
              <Icon size={17} /> <span>{label}</span>
              {id === 'emergencies' && data.stats.activeSosCount > 0 && <b>{data.stats.activeSosCount}</b>}
            </button>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <span className="secure-label"><span className="secure-dot" /> Admin session</span>
          <button className="nav-item signout-button" onClick={signOut}><LogOut size={17} /> Sign out</button>
        </div>
      </aside>

      <main className="main-content">
        <header className="topbar">
          <div className="page-title">
            <div className="page-kicker"><ViewIcon size={14} /> SAFEHER / {activeView?.label.toUpperCase()}</div>
            <h1>{view === 'overview' ? 'Emergency operations' : activeView?.label}</h1>
            <p>Mobile safety activity and response status</p>
          </div>
          <div className="topbar-actions">
            <div className="connection-state">
              <span className={`connection-dot ${error ? 'offline' : ''}`} />
              {error ? 'Connection issue' : 'API connected'}
              {updatedAt && <small>Updated {formatDate(updatedAt.toISOString())}</small>}
            </div>
            <button className="icon-button" title="Refresh data" aria-label="Refresh data" onClick={() => setRefreshKey((key) => key + 1)} disabled={loading}>
              <RefreshCw size={17} className={loading ? 'spin' : ''} />
            </button>
            <button className="user-menu" onClick={signOut} title={`Signed in as ${session.name}`}>
              <span className="avatar">{session.name.slice(0, 1).toUpperCase()}</span>
              <span>{session.name}</span>
              <LogOut size={15} />
            </button>
          </div>
        </header>

        {error && (
          <div className="error-banner" role="alert">
            <AlertTriangle size={17} /> <span>{error}</span>
            <button onClick={() => setRefreshKey((key) => key + 1)}>Retry</button>
          </div>
        )}

        {view === 'overview' && <Overview data={data} deliveryRate={deliveryRate} onOpen={setView} />}
        {view === 'emergencies' && <EmergencyView emergencies={data.emergencies} />}
        {view === 'journeys' && <JourneyView journeys={data.journeys} />}
        {view === 'checkins' && <CheckInView checkins={data.checkins} />}
        {view === 'contacts' && <ContactView contacts={data.contacts} />}
        {view === 'deliveries' && <DeliveryView deliveries={data.deliveries} />}
        {view === 'users' && <UserView users={data.users} />}
      </main>
    </div>
  );
}

function Overview({ data, deliveryRate, onOpen }: Readonly<{ data: DashboardData; deliveryRate: string; onOpen: (view: View) => void }>) {
  return (
    <>
      <section className="metrics-grid" aria-label="Live platform metrics">
        <Metric label="Active SOS" value={data.stats.activeSosCount} icon={AlertTriangle} tone="red" onClick={() => onOpen('emergencies')} />
        <Metric label="Active safe walks" value={data.stats.activeJourneysCount} icon={MapPin} tone="blue" onClick={() => onOpen('journeys')} />
        <Metric label="Pending check-ins" value={data.stats.pendingCheckinsCount} icon={Clock3} tone="amber" onClick={() => onOpen('checkins')} />
        <Metric label="Delivery success" value={deliveryRate} icon={CheckCircle2} tone="green" onClick={() => onOpen('deliveries')} />
        <Metric label="Protected users" value={data.stats.totalUsersCount} icon={Users} tone="teal" onClick={() => onOpen('users')} />
      </section>

      <div className="overview-grid">
        <Panel title="Active distress incidents" detail={`${data.emergencies.length} active mobile alert${data.emergencies.length === 1 ? '' : 's'}`}>
          <DataTable<Emergency>
            columns={['Incident', 'User', 'Last location', 'Started', 'Status']}
            rows={data.emergencies.slice(0, 6)}
            empty="No active SOS events."
            renderRow={(event) => (
              <tr>
                <td className="id-cell">#{event.id}</td>
                <td><strong>{event.userName}</strong><small>{event.userPhone}</small></td>
                <td><LocationLink latitude={event.latitude} longitude={event.longitude} /></td>
                <td>{formatDate(event.startedAt)}</td>
                <td><Status value={event.status} /></td>
              </tr>
            )}
          />
          <button className="text-action" onClick={() => onOpen('emergencies')}>View all active SOS <span>→</span></button>
        </Panel>

        <Panel title="Safe walk activity" detail="Latest mobile journeys">
          <DataTable<Journey>
            columns={['User', 'Destination', 'Arrival', 'Status']}
            rows={data.journeys.filter((journey) => journey.status === 'ACTIVE').slice(0, 6)}
            empty="No active safe walks."
            renderRow={(journey) => (
              <tr>
                <td><strong>{journey.userName}</strong><small>{journey.userPhone}</small></td>
                <td>{journey.destination}</td>
                <td>{formatDate(journey.expectedArrival)}</td>
                <td><Status value={journey.status} /></td>
              </tr>
            )}
          />
          <button className="text-action" onClick={() => onOpen('journeys')}>View all safe walks <span>→</span></button>
        </Panel>
      </div>

      <div className="overview-footer">
        <span><Clock3 size={15} /> Auto-refresh every 15 seconds</span>
        <span className={data.stats.failedDeliveriesCount > 0 ? 'failure-count' : ''}>
          <Send size={15} /> {data.stats.failedDeliveriesCount} failed alert deliveries
        </span>
      </div>
    </>
  );
}

function Metric({ label, value, icon: Icon, tone, onClick }: Readonly<{ label: string; value: string | number; icon: typeof Activity; tone: string; onClick: () => void }>) {
  return (
    <button className={`metric metric-${tone}`} onClick={onClick}>
      <span className="metric-icon"><Icon size={18} /></span>
      <span className="metric-label">{label}</span>
      <strong>{value}</strong>
      <span className="metric-link">Open view <span>→</span></span>
    </button>
  );
}

function EmergencyView({ emergencies }: Readonly<{ emergencies: Emergency[] }>) {
  return (
    <Panel title="Active SOS events" detail="SOS status and the latest location submitted by the mobile app">
      <DataTable<Emergency>
        columns={['Incident', 'User', 'Type', 'Latest location', 'Location time', 'Started', 'Status']}
        rows={emergencies}
        empty="No active SOS events."
        renderRow={(event) => (
          <tr>
            <td className="id-cell">#{event.id}</td>
            <td><strong>{event.userName}</strong><small>{event.userPhone}</small></td>
            <td>{replaceUnderscores(event.eventType, ' ')}</td>
            <td><LocationLink latitude={event.latitude} longitude={event.longitude} /></td>
            <td>{formatDate(event.locationRecordedAt)}</td>
            <td>{formatDate(event.startedAt)}</td>
            <td><Status value={event.status} /></td>
          </tr>
        )}
      />
    </Panel>
  );
}

function JourneyView({ journeys }: Readonly<{ journeys: Journey[] }>) {
  return (
    <Panel title="Safe walks" detail="Journey destination, expected arrival, and completion status">
      <DataTable<Journey>
        columns={['User', 'Destination', 'Started', 'Expected arrival', 'Grace period', 'Status']}
        rows={journeys}
        empty="No safe-walk journeys recorded."
        renderRow={(journey) => (
          <tr>
            <td><strong>{journey.userName}</strong><small>{journey.userPhone}</small></td>
            <td>{journey.destination}</td>
            <td>{formatDate(journey.startedAt)}</td>
            <td>{formatDate(journey.expectedArrival)}</td>
            <td>{journey.gracePeriodMinutes} min</td>
            <td><Status value={journey.status} /></td>
          </tr>
        )}
      />
    </Panel>
  );
}

function CheckInView({ checkins }: Readonly<{ checkins: CheckIn[] }>) {
  return (
    <Panel title="Safety check-ins" detail="Scheduled and completed confirmations from mobile users">
      <DataTable<CheckIn>
        columns={['User', 'Scheduled', 'Grace period', 'Last prompted', 'Completed', 'Status']}
        rows={checkins}
        empty="No scheduled check-ins."
        renderRow={(checkin) => (
          <tr>
            <td><strong>{checkin.userName}</strong><small>{checkin.userPhone}</small></td>
            <td>{formatDate(checkin.scheduledTime)}</td>
            <td>{checkin.gracePeriodMinutes} min</td>
            <td>{formatDate(checkin.lastPromptedAt)}</td>
            <td>{formatDate(checkin.completedAt)}</td>
            <td><Status value={checkin.status} /></td>
          </tr>
        )}
      />
    </Panel>
  );
}

function ContactView({ contacts }: Readonly<{ contacts: EmergencyContact[] }>) {
  return (
    <Panel title="Emergency contacts" detail="Trusted contacts configured by mobile users">
      <DataTable<EmergencyContact>
        columns={['Contact', 'Phone', 'Relationship', 'SafeHer user', 'Priority', 'Notifications', 'Verified']}
        rows={contacts}
        empty="No emergency contacts registered."
        renderRow={(contact) => (
          <tr>
            <td><strong>{contact.contactName}</strong></td>
            <td>{contact.phone}</td>
            <td>{contact.relationship || '—'}</td>
            <td><strong>{contact.userName}</strong><small>{contact.userPhone}</small></td>
            <td>{contact.priority}</td>
            <td>{[contact.notifySms && 'SMS', contact.notifyPush && 'Push'].filter(Boolean).join(' · ') || 'None'}</td>
            <td><Status value={contact.verified ? 'VERIFIED' : 'PENDING'} /></td>
          </tr>
        )}
      />
    </Panel>
  );
}

function DeliveryView({ deliveries }: Readonly<{ deliveries: Delivery[] }>) {
  return (
    <Panel title="Alert deliveries" detail="SMS, gateway, and push delivery results">
      <DataTable<Delivery>
        columns={['Delivery', 'Incident', 'Recipient', 'Channel', 'Provider ref', 'Sent', 'Status']}
        rows={deliveries}
        empty="No alert deliveries recorded."
        renderRow={(delivery) => (
          <tr>
            <td className="id-cell">#{delivery.id}</td>
            <td>{delivery.emergencyEventId ? `#${delivery.emergencyEventId}` : '—'}</td>
            <td>{delivery.recipientPhone}</td>
            <td>{replaceUnderscores(delivery.channel, ' ')}</td>
            <td>{delivery.providerRef || '—'}</td>
            <td>{formatDate(delivery.sentAt)}</td>
            <td><Status value={delivery.status} /></td>
          </tr>
        )}
      />
    </Panel>
  );
}

function UserView({ users }: Readonly<{ users: AdminUser[] }>) {
  return (
    <Panel title="SafeHer users" detail="Account state and most recent activity">
      <DataTable<AdminUser>
        columns={['User', 'Phone', 'Role', 'Joined', 'Last login', 'Verified', 'Account']}
        rows={users}
        empty="No user accounts found."
        renderRow={(user) => (
          <tr>
            <td><strong>{user.name}</strong><small>{user.email}</small></td>
            <td>{user.phone}</td>
            <td>{user.role.replace('ROLE_', '')}</td>
            <td>{formatDate(user.createdAt)}</td>
            <td>{formatDate(user.lastLoginAt)}</td>
            <td><Status value={user.verified ? 'VERIFIED' : 'PENDING'} /></td>
            <td><Status value={user.accountStatus} /></td>
          </tr>
        )}
      />
    </Panel>
  );
}

function LocationLink({ latitude, longitude }: Readonly<{ latitude: number | null; longitude: number | null }>) {
  if (latitude === null || longitude === null) return <span className="muted">No location yet</span>;
  return (
    <a className="map-link" href={`https://maps.google.com/?q=${latitude},${longitude}`} target="_blank" rel="noreferrer">
      <MapPin size={14} /> {latitude.toFixed(5)}, {longitude.toFixed(5)}
    </a>
  );
}