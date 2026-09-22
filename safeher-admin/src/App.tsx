import React, { useState } from 'react';
import { Shield, AlertTriangle, Radio, Users, CheckCircle2, Clock, MapPin, RefreshCw, Send } from 'lucide-react';

export default function App() {
  const [activeTab, setActiveTab] = useState<'overview' | 'emergencies' | 'deliveries'>('overview');

  // Sample operational state
  const stats = {
    activeSos: 2,
    activeJourneys: 14,
    pendingCheckins: 8,
    totalUsers: 1420,
    successfulDeliveries: '98.4%',
  };

  const sampleEmergencies = [
    { id: '104', user: 'Pooja Sharma', phone: '+91 98765 11223', type: 'SOS', time: '2 mins ago', status: 'ACTIVE', lat: 28.6139, lng: 77.2090 },
    { id: '103', user: 'Sneha Verma', phone: '+91 98765 33445', type: 'SAFE_WALK_OVERDUE', time: '11 mins ago', status: 'ESCALATED', lat: 19.0760, lng: 72.8777 },
  ];

  const sampleDeliveries = [
    { id: 'DEL-882', eventId: '#104', recipient: '+91 98765 43210', channel: 'GATEWAY_SMS (MSG91)', status: 'DELIVERED', time: '11:24:02 AM' },
    { id: 'DEL-881', eventId: '#104', recipient: '+91 98765 43211', channel: 'NATIVE_SMS', status: 'SENT', time: '11:24:00 AM' },
    { id: 'DEL-880', eventId: '#103', recipient: '+91 98765 99887', channel: 'GATEWAY_SMS (MSG91)', status: 'DELIVERED', time: '11:15:30 AM' },
  ];

  return (
    <div style={{ display: 'flex', minHeight: '100vh', backgroundColor: '#0f172a' }}>
      {/* Sidebar */}
      <aside style={{ width: '260px', backgroundColor: '#1e293b', borderRight: '1px solid #334155', padding: '24px 16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '36px', paddingLeft: '8px' }}>
          <div style={{ backgroundColor: '#ef4444', padding: '8px', borderRadius: '10px', display: 'flex' }}>
            <Shield size={24} color="#ffffff" />
          </div>
          <div>
            <h1 style={{ fontSize: '18px', fontWeight: '800', letterSpacing: '0.5px' }}>SafeHer</h1>
            <p style={{ fontSize: '11px', color: '#94a3b8' }}>Operations Command</p>
          </div>
        </div>

        <nav style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          <button
            onClick={() => setActiveTab('overview')}
            style={{
              display: 'flex', alignItems: 'center', gap: '12px', width: '100%', padding: '12px 16px',
              borderRadius: '8px', fontSize: '14px', fontWeight: '600', textAlign: 'left',
              backgroundColor: activeTab === 'overview' ? '#ef4444' : 'transparent',
              color: activeTab === 'overview' ? '#ffffff' : '#94a3b8',
            }}
          >
            <Radio size={18} /> Overview
          </button>
          <button
            onClick={() => setActiveTab('emergencies')}
            style={{
              display: 'flex', alignItems: 'center', gap: '12px', width: '100%', padding: '12px 16px',
              borderRadius: '8px', fontSize: '14px', fontWeight: '600', textAlign: 'left',
              backgroundColor: activeTab === 'emergencies' ? '#ef4444' : 'transparent',
              color: activeTab === 'emergencies' ? '#ffffff' : '#94a3b8',
            }}
          >
            <AlertTriangle size={18} /> Active SOS ({stats.activeSos})
          </button>
          <button
            onClick={() => setActiveTab('deliveries')}
            style={{
              display: 'flex', alignItems: 'center', gap: '12px', width: '100%', padding: '12px 16px',
              borderRadius: '8px', fontSize: '14px', fontWeight: '600', textAlign: 'left',
              backgroundColor: activeTab === 'deliveries' ? '#ef4444' : 'transparent',
              color: activeTab === 'deliveries' ? '#ffffff' : '#94a3b8',
            }}
          >
            <Send size={18} /> SMS & Alerts
          </button>
        </nav>
      </aside>

      {/* Main Content */}
      <main style={{ flex: 1, padding: '32px 40px', overflowY: 'auto' }}>
        {/* Header */}
        <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
          <div>
            <h2 style={{ fontSize: '24px', fontWeight: '700' }}>Emergency Operations HUD</h2>
            <p style={{ color: '#94a3b8', fontSize: '14px' }}>Real-time emergency telemetry and multi-channel delivery status</p>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <span style={{ display: 'flex', alignItems: 'center', gap: '8px', backgroundColor: '#1e293b', padding: '8px 16px', borderRadius: '8px', fontSize: '13px', color: '#10b981', fontWeight: '600' }}>
              <span style={{ width: '8px', height: '8px', backgroundColor: '#10b981', borderRadius: '50%' }}></span> System Operational
            </span>
            <button style={{ display: 'flex', alignItems: 'center', gap: '8px', backgroundColor: '#334155', color: '#f8fafc', padding: '8px 16px', borderRadius: '8px', fontSize: '13px' }}>
              <RefreshCw size={14} /> Refresh
            </button>
          </div>
        </header>

        {/* Stats Strip */}
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '20px', marginBottom: '32px' }}>
          <div style={{ backgroundColor: '#1e293b', border: '1px solid #334155', padding: '20px', borderRadius: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', color: '#ef4444', marginBottom: '8px' }}>
              <span style={{ fontSize: '13px', fontWeight: '600' }}>Active Emergencies</span>
              <AlertTriangle size={18} />
            </div>
            <p style={{ fontSize: '32px', fontWeight: '800' }}>{stats.activeSos}</p>
          </div>
          <div style={{ backgroundColor: '#1e293b', border: '1px solid #334155', padding: '20px', borderRadius: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', color: '#3b82f6', marginBottom: '8px' }}>
              <span style={{ fontSize: '13px', fontWeight: '600' }}>Active Safe Walks</span>
              <MapPin size={18} />
            </div>
            <p style={{ fontSize: '32px', fontWeight: '800' }}>{stats.activeJourneys}</p>
          </div>
          <div style={{ backgroundColor: '#1e293b', border: '1px solid #334155', padding: '20px', borderRadius: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', color: '#10b981', marginBottom: '8px' }}>
              <span style={{ fontSize: '13px', fontWeight: '600' }}>SMS Delivery Rate</span>
              <CheckCircle2 size={18} />
            </div>
            <p style={{ fontSize: '32px', fontWeight: '800' }}>{stats.successfulDeliveries}</p>
          </div>
          <div style={{ backgroundColor: '#1e293b', border: '1px solid #334155', padding: '20px', borderRadius: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', color: '#a855f7', marginBottom: '8px' }}>
              <span style={{ fontSize: '13px', fontWeight: '600' }}>Protected Users</span>
              <Users size={18} />
            </div>
            <p style={{ fontSize: '32px', fontWeight: '800' }}>{stats.totalUsers}</p>
          </div>
        </section>

        {/* Live Active Emergencies Table */}
        <section style={{ backgroundColor: '#1e293b', border: '1px solid #334155', borderRadius: '12px', padding: '24px', marginBottom: '32px' }}>
          <h3 style={{ fontSize: '16px', fontWeight: '700', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <AlertTriangle size={18} color="#ef4444" /> Live Distress Incidents
          </h3>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '14px' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid #334155', color: '#94a3b8' }}>
                <th style={{ padding: '12px 8px' }}>Event ID</th>
                <th style={{ padding: '12px 8px' }}>User</th>
                <th style={{ padding: '12px 8px' }}>Trigger Type</th>
                <th style={{ padding: '12px 8px' }}>Live Location</th>
                <th style={{ padding: '12px 8px' }}>Started</th>
                <th style={{ padding: '12px 8px' }}>Status</th>
              </tr>
            </thead>
            <tbody>
              {sampleEmergencies.map((e) => (
                <tr key={e.id} style={{ borderBottom: '1px solid #334155' }}>
                  <td style={{ padding: '16px 8px', fontWeight: '700' }}>#{e.id}</td>
                  <td style={{ padding: '16px 8px' }}>
                    <div>{e.user}</div>
                    <div style={{ fontSize: '12px', color: '#94a3b8' }}>{e.phone}</div>
                  </td>
                  <td style={{ padding: '16px 8px' }}>
                    <span style={{ backgroundColor: '#7f1d1d', color: '#fca5a5', padding: '4px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: '700' }}>
                      {e.type}
                    </span>
                  </td>
                  <td style={{ padding: '16px 8px' }}>
                    <a
                      href={`https://maps.google.com/?q=${e.lat},${e.lng}`}
                      target="_blank"
                      rel="noreferrer"
                      style={{ color: '#38bdf8', textDecoration: 'none', display: 'inline-flex', alignItems: 'center', gap: '4px' }}
                    >
                      <MapPin size={14} /> View Map ({e.lat}, {e.lng})
                    </a>
                  </td>
                  <td style={{ padding: '16px 8px', color: '#94a3b8' }}>{e.time}</td>
                  <td style={{ padding: '16px 8px' }}>
                    <span style={{ backgroundColor: '#064e3b', color: '#6ee7b7', padding: '4px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: '700' }}>
                      {e.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>

        {/* Multi-Channel Deliveries */}
        <section style={{ backgroundColor: '#1e293b', border: '1px solid #334155', borderRadius: '12px', padding: '24px' }}>
          <h3 style={{ fontSize: '16px', fontWeight: '700', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Send size={18} color="#38bdf8" /> Recent Alert Dispatches (DLT & Native SMS Tracking)
          </h3>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '14px' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid #334155', color: '#94a3b8' }}>
                <th style={{ padding: '12px 8px' }}>Delivery Ref</th>
                <th style={{ padding: '12px 8px' }}>Emergency Ref</th>
                <th style={{ padding: '12px 8px' }}>Recipient</th>
                <th style={{ padding: '12px 8px' }}>Channel</th>
                <th style={{ padding: '12px 8px' }}>Status</th>
                <th style={{ padding: '12px 8px' }}>Timestamp</th>
              </tr>
            </thead>
            <tbody>
              {sampleDeliveries.map((d) => (
                <tr key={d.id} style={{ borderBottom: '1px solid #334155' }}>
                  <td style={{ padding: '14px 8px', fontWeight: '600' }}>{d.id}</td>
                  <td style={{ padding: '14px 8px' }}>{d.eventId}</td>
                  <td style={{ padding: '14px 8px' }}>{d.recipient}</td>
                  <td style={{ padding: '14px 8px', color: '#94a3b8' }}>{d.channel}</td>
                  <td style={{ padding: '14px 8px' }}>
                    <span style={{ color: d.status === 'DELIVERED' ? '#34d399' : '#60a5fa', fontWeight: '600' }}>
                      {d.status}
                    </span>
                  </td>
                  <td style={{ padding: '14px 8px', color: '#94a3b8' }}>{d.time}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </main>
    </div>
  );
}
