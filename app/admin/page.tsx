'tsx'
'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@supabase/supabase-js';

// Initialize public client for reading analytics/orders
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL || '',
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''
);

export default function AdminDashboard() {
  const [events, setEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchAdminData() {
      try {
        setLoading(true);
        // Fetch events along with organization details
        const { data, error } = await supabase
          .from('events')
          .select('id, title, status, starts_at, organizations(name)')
          .order('starts_at', { ascending: true });

        if (error) throw error;
        setEvents(data || []);
      } catch (err: any) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    }

    fetchAdminData();
  }, []);

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 p-8 font-sans">
      <div className="max-w-6xl mx-auto">
        <header className="flex justify-between items-center mb-8 pb-4 border-b border-slate-800">
          <div>
            <h1 className="text-3xl font-extrabold tracking-tight text-white">Ticketing Admin Dashboard</h1>
            <p className="text-slate-400 text-sm mt-1">Monitor events, inventory levels, and live ticket sales.</p>
          </div>
          <span className="bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 text-xs font-semibold px-3 py-1 rounded-full">
            System Online
          </span>
        </header>

        {error && (
          <div className="bg-red-500/10 border border-red-500/20 text-red-400 p-4 rounded-lg mb-6 text-sm">
            Error loading data: {error}
          </div>
        )}

        {loading ? (
          <div className="text-center py-20 text-slate-400 animate-pulse">Loading admin dashboard...</div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {events.map((evt) => (
              <div key={evt.id} className="bg-slate-800 border border-slate-700/60 rounded-xl p-6 shadow-xl hover:border-slate-600 transition-all">
                <div className="flex justify-between items-start mb-4">
                  <span className="text-xs uppercase tracking-wider font-semibold bg-indigo-500/10 text-indigo-400 px-2.5 py-1 rounded">
                    {evt.status}
                  </span>
                  <span className="text-xs text-slate-400">
                    {new Date(evt.starts_at).toLocaleDateString()}
                  </span>
                </div>
                <h3 className="text-lg font-bold text-white mb-1">{evt.title}</h3>
                <p className="text-xs text-slate-400 mb-6">Org: {evt.organizations?.name || 'N/A'}</p>
                <div className="flex justify-between items-center pt-4 border-t border-slate-700/50 text-xs">
                  <span className="text-slate-400">Event ID</span>
                  <span className="font-mono text-slate-300">{evt.id.slice(0, 8)}...</span>
                </div>
              </div>
            ))}
            {events.length === 0 && !loading && (
              <div className="col-span-full text-center py-12 text-slate-400 bg-slate-800/50 rounded-xl border border-slate-800">
                No events found. Seed your database to see items here.
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
