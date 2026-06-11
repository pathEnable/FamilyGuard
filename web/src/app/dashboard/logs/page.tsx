"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { fetchAPI, logout } from "@/lib/api";
import { Shield, ArrowLeft, ShieldAlert, Clock, Smartphone, Activity, Filter, Search } from "lucide-react";

type ActivityLog = {
  id: number;
  profile_id: number;
  profile_name: string;
  activity_type: string;
  description: string;
  created_at: string;
};

type Profile = {
  id: number;
  name: string;
};

export default function GlobalLogsPage() {
  const [logs, setLogs] = useState<ActivityLog[]>([]);
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  
  // Filters
  const [selectedProfileId, setSelectedProfileId] = useState<string>("all");
  const [selectedType, setSelectedType] = useState<string>("all");

  // Pagination
  const [page, setPage] = useState(1);
  const [totalItems, setTotalItems] = useState(0);
  const limit = 50;

  const router = useRouter();

  useEffect(() => {
    const loadData = async () => {
      try {
        setLoading(true);
        const skip = (page - 1) * limit;
        // Fetch logs and profiles concurrently
        const [logsResponse, profilesData] = await Promise.all([
          fetchAPI(`/profiles/logs/all?skip=${skip}&limit=${limit}`),
          fetchAPI("/profiles/")
        ]);
        
        setLogs(logsResponse.items || []);
        setTotalItems(logsResponse.total || 0);
        setProfiles(profilesData.map((p: any) => ({ id: p.id, name: p.name })));
      } catch (err: any) {
        if (err.message.includes("Non autorisé") || err.message.includes("credentials")) {
          logout();
          router.push("/login");
        } else {
          setError("Impossible de charger l'historique.");
        }
      } finally {
        setLoading(false);
      }
    };
    loadData();
  }, [router, page]);

  // Filtering logic
  const filteredLogs = logs.filter(log => {
    const matchProfile = selectedProfileId === "all" || log.profile_id.toString() === selectedProfileId;
    const matchType = selectedType === "all" || log.activity_type === selectedType;
    return matchProfile && matchType;
  });

  const totalPages = Math.ceil(totalItems / limit);

  return (
    <div className="min-h-screen bg-mesh text-text-main pb-20">
      {/* Navigation */}
      <nav className="sticky top-0 z-50 glass border-b border-white/20 px-6 py-4">
        <div className="max-w-6xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Link href="/dashboard" className="p-2 hover:bg-white/50 rounded-lg transition-colors text-text-muted hover:text-primary">
              <ArrowLeft className="w-5 h-5" />
            </Link>
            <div className="w-10 h-10 bg-gradient-to-br from-primary to-primary-dark rounded-xl flex items-center justify-center shadow-lg shadow-primary/20">
              <Activity className="w-5 h-5 text-white" />
            </div>
            <h1 className="text-xl font-bold text-gray-900">
              Historique Global
            </h1>
          </div>
        </div>
      </nav>

      <main className="max-w-6xl mx-auto px-6 mt-8 animate-slide-up">
        {error && (
          <div className="mb-6 bg-danger/10 border border-danger/20 text-danger px-4 py-3 rounded-xl">
            {error}
          </div>
        )}

        <div className="glass bg-white/70 p-6 rounded-2xl shadow-sm border border-white/50 mb-8">
          <div className="flex flex-col md:flex-row gap-4 justify-between items-start md:items-center">
            <div className="flex items-center gap-2 text-primary font-medium">
              <Filter className="w-5 h-5" />
              <span>Filtres</span>
            </div>
            <div className="flex flex-col sm:flex-row gap-3 w-full md:w-auto">
              <select 
                value={selectedProfileId}
                onChange={(e) => setSelectedProfileId(e.target.value)}
                className="bg-white border border-gray-200 text-gray-700 rounded-lg px-4 py-2 focus:ring-2 focus:ring-primary/50 focus:border-primary outline-none"
              >
                <option value="all">Tous les enfants</option>
                {profiles.map(p => (
                  <option key={p.id} value={p.id}>{p.name}</option>
                ))}
              </select>
              
              <select 
                value={selectedType}
                onChange={(e) => setSelectedType(e.target.value)}
                className="bg-white border border-gray-200 text-gray-700 rounded-lg px-4 py-2 focus:ring-2 focus:ring-primary/50 focus:border-primary outline-none"
              >
                <option value="all">Tous les événements</option>
                <option value="SOS_TRIGGERED">SOS (Urgence)</option>
                <option value="WEB_BLOCKED">Sites Web Bloqués</option>
                <option value="TIME_LIMIT_REACHED">Limites de Temps</option>
              </select>
            </div>
          </div>
        </div>

        {loading ? (
          <div className="flex justify-center items-center h-64">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
          </div>
        ) : filteredLogs.length === 0 ? (
          <div className="glass p-16 text-center rounded-2xl border border-white/40">
            <Search className="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <h3 className="text-xl font-bold text-gray-900 mb-2">Aucun historique trouvé</h3>
            <p className="text-text-muted">Il n'y a aucune activité correspondant à ces filtres.</p>
          </div>
        ) : (
          <div className="glass bg-white/80 p-6 rounded-2xl shadow-sm border border-white/50">
            <div className="relative border-l-2 border-gray-100 ml-4 md:ml-6 space-y-8 py-4">
              {filteredLogs.map((log) => {
                const isSOS = log.activity_type === 'SOS_TRIGGERED';
                const isBlocked = log.activity_type === 'WEB_BLOCKED';
                const isTime = log.activity_type === 'TIME_LIMIT_REACHED';

                let dotColor = 'bg-primary';
                let icon = <Smartphone className="w-4 h-4" />;
                if (isSOS) {
                  dotColor = 'bg-danger border-danger/20';
                  icon = <ShieldAlert className="w-4 h-4 text-white" />;
                } else if (isBlocked) {
                  dotColor = 'bg-warning border-warning/20';
                  icon = <ShieldAlert className="w-4 h-4 text-white" />;
                } else if (isTime) {
                  dotColor = 'bg-gray-500 border-gray-200';
                  icon = <Clock className="w-4 h-4 text-white" />;
                }

                return (
                  <div key={log.id} className="relative pl-8 md:pl-10">
                    <div className={`absolute -left-[17px] top-1 w-8 h-8 rounded-full border-4 shadow-sm flex items-center justify-center ${dotColor} ${isSOS || isBlocked || isTime ? 'border-white' : 'border-white text-white'}`}>
                      {icon}
                    </div>
                    
                    <div className="bg-white p-4 rounded-xl border border-gray-100 shadow-sm hover:shadow-md transition-shadow">
                      <div className="flex flex-col md:flex-row md:justify-between md:items-start gap-2">
                        <div>
                          <div className="flex items-center gap-2 mb-1">
                            <span className="font-bold text-gray-900">{log.profile_name}</span>
                            <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                              isSOS ? 'bg-danger/10 text-danger' : 
                              isBlocked ? 'bg-warning/10 text-warning' : 
                              isTime ? 'bg-gray-100 text-gray-600' : 'bg-primary/10 text-primary'
                            }`}>
                              {isSOS ? 'SOS' : isBlocked ? 'Web Bloqué' : isTime ? 'Temps Écoulé' : 'Activité'}
                            </span>
                          </div>
                          <p className="text-gray-800">{log.description}</p>
                        </div>
                        <div className="text-sm font-medium text-text-muted whitespace-nowrap bg-gray-50 px-3 py-1 rounded-lg">
                          {new Date(log.created_at).toLocaleString('fr-FR', { 
                            weekday: 'short', day: '2-digit', month: 'short', hour: '2-digit', minute:'2-digit' 
                          })}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
            
            {/* Pagination Controls */}
            {totalPages > 1 && (
              <div className="flex justify-between items-center mt-8 pt-6 border-t border-gray-100">
                <button 
                  onClick={() => setPage(p => Math.max(1, p - 1))}
                  disabled={page === 1}
                  className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  Précédent
                </button>
                <div className="text-sm text-text-muted">
                  Page <span className="font-medium text-gray-900">{page}</span> sur <span className="font-medium text-gray-900">{totalPages}</span>
                </div>
                <button 
                  onClick={() => setPage(p => Math.min(totalPages, p + 1))}
                  disabled={page === totalPages}
                  className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  Suivant
                </button>
              </div>
            )}
          </div>
        )}
      </main>
    </div>
  );
}
