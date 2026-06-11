"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { fetchAPI, logout } from "@/lib/api";
import { useWebSocket } from "@/hooks/useWebSocket";
import { Shield, LogOut, Plus, ChevronRight, Activity, Clock, ShieldAlert, MoreVertical, Edit2, Trash2 } from "lucide-react";
import ProfileModal from "@/components/ProfileModal";

type Profile = {
  id: string;
  name: string;
  age: number;
  avatar_url?: string;
  is_active: boolean;
  formatted_usage?: string;
  alert_count?: number;
};

export default function DashboardPage() {
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingProfile, setEditingProfile] = useState<Profile | null>(null);
  const [activeMenuId, setActiveMenuId] = useState<string | null>(null);
  const router = useRouter();

  // Initialize real-time WebSocket connection
  useWebSocket();

  const loadData = async () => {
    try {
      const data = await fetchAPI("/profiles/");
      
      // Fetch daily usage for each profile concurrently
      const profilesWithUsage = await Promise.all(
        data.map(async (profile: Profile) => {
          try {
            const usageData = await fetchAPI(`/profiles/${profile.id}/daily-usage`);
            return { 
              ...profile, 
              formatted_usage: usageData.formatted,
              alert_count: usageData.alert_count 
            };
          } catch {
            return { ...profile, formatted_usage: "0h 00m", alert_count: 0 };
          }
        })
      );
      
      setProfiles(profilesWithUsage);
    } catch (err: any) {
      if (err.message.includes("Non autorisé") || err.message.includes("Could not validate credentials")) {
        logout();
        router.push("/login");
      } else {
        setError(err.message || "Impossible de charger les profils");
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
    
    // Request push notification permission
    if ("Notification" in window) {
      if (Notification.permission === "default") {
        Notification.requestPermission();
      }
    }
  }, [router]);

  const handleDelete = async (e: React.MouseEvent, id: string) => {
    e.preventDefault();
    e.stopPropagation();
    if (!confirm("Voulez-vous vraiment supprimer ce profil ? Toutes les données seront perdues.")) return;
    
    try {
      await fetchAPI(`/profiles/${id}`, { method: "DELETE" });
      loadData();
    } catch (err: any) {
      setError(err.message || "Erreur lors de la suppression");
    }
    setActiveMenuId(null);
  };

  const handleEdit = (e: React.MouseEvent, profile: Profile) => {
    e.preventDefault();
    e.stopPropagation();
    setEditingProfile(profile);
    setIsModalOpen(true);
    setActiveMenuId(null);
  };

  const handleLogout = () => {
    logout();
    router.push("/login");
  };

  return (
    <div className="min-h-screen bg-mesh text-text-main pb-20">
      {/* Premium Glassmorphism Navigation */}
      <nav className="sticky top-0 z-50 glass border-b border-white/20 px-6 py-4">
        <div className="max-w-6xl mx-auto flex justify-between items-center">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-br from-primary to-primary-dark rounded-xl flex items-center justify-center shadow-lg shadow-primary/20">
              <Shield className="w-5 h-5 text-white" />
            </div>
            <h1 className="text-xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-gray-900 to-gray-700">
              SafeChild
            </h1>
          </div>
          <div className="flex items-center gap-4">
            <Link href="/dashboard/logs" className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-text-muted hover:text-primary hover:bg-white/50 rounded-lg transition-all">
              <Activity className="w-4 h-4" />
              <span className="hidden sm:inline">Historique</span>
            </Link>
            <button
              onClick={handleLogout}
              className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-text-muted hover:text-danger hover:bg-danger/5 rounded-lg transition-all"
            >
              <LogOut className="w-4 h-4" />
              <span className="hidden sm:inline">Déconnexion</span>
            </button>
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-6xl mx-auto px-6 mt-12 animate-slide-up">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-10 gap-4">
          <div>
            <h2 className="text-3xl font-bold text-gray-900 tracking-tight">Vos Enfants</h2>
            <p className="text-text-muted mt-1">Gérez la sécurité et le temps d'écran de votre famille</p>
          </div>
          <button 
            onClick={() => { setEditingProfile(null); setIsModalOpen(true); }}
            className="group relative bg-gradient-to-r from-primary to-primary-dark hover:from-primary-dark hover:to-[#173587] text-white px-5 py-2.5 rounded-xl font-medium transition-all shadow-md shadow-primary/20 flex items-center gap-2 overflow-hidden"
          >
            <div className="absolute inset-0 bg-white/20 translate-y-full group-hover:translate-y-0 transition-transform duration-300"></div>
            <Plus className="w-5 h-5 relative z-10" />
            <span className="relative z-10">Ajouter un profil</span>
          </button>
        </div>

        {error && (
          <div className="bg-danger/10 border border-danger/20 text-danger p-4 rounded-xl mb-8 flex items-center gap-3 animate-fade-in">
            <ShieldAlert className="w-5 h-5" />
            {error}
          </div>
        )}

        {loading ? (
          <div className="flex justify-center items-center py-24">
            <div className="relative w-16 h-16">
              <div className="absolute inset-0 rounded-full border-t-2 border-primary animate-spin"></div>
              <div className="absolute inset-2 rounded-full border-r-2 border-primary-light animate-spin" style={{ animationDirection: 'reverse', animationDuration: '1.5s' }}></div>
            </div>
          </div>
        ) : profiles.length === 0 ? (
          <div className="glass p-16 text-center rounded-2xl shadow-xl border border-white/40 max-w-2xl mx-auto mt-10">
            <div className="w-24 h-24 bg-gradient-to-br from-primary-light to-white text-primary rounded-full flex items-center justify-center mx-auto mb-6 shadow-inner border border-primary/10">
              <Activity className="w-10 h-10" />
            </div>
            <h3 className="text-2xl font-bold text-gray-900 mb-3">Aucun profil configuré</h3>
            <p className="text-text-muted mb-8 leading-relaxed">
              Vous n'avez pas encore configuré de profil pour vos enfants. Ajoutez-en un pour commencer à suivre leur activité et gérer leur temps d'écran.
            </p>
            <button className="bg-white border border-gray-200 hover:border-primary/50 hover:bg-primary/5 text-gray-800 px-6 py-3 rounded-xl font-medium transition-all shadow-sm">
              Créer mon premier profil
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {profiles.map((profile, idx) => (
              <Link 
                href={`/dashboard/${profile.id}`} 
                key={profile.id}
                className="group block"
                style={{ animationDelay: `${idx * 100}ms` }}
              >
                <div className="glass bg-white/60 hover:bg-white/90 p-6 rounded-2xl shadow-sm hover:shadow-xl hover:shadow-primary/5 border border-white/50 hover:border-primary/20 transition-all duration-300 transform hover:-translate-y-1">
                  <div className="flex items-center justify-between gap-5 mb-6">
                    <div className="flex items-center gap-5">
                      <div className="relative">
                        <div className="w-16 h-16 bg-gradient-to-br from-primary-light to-white rounded-2xl flex items-center justify-center text-2xl font-bold text-primary shadow-inner border border-primary/10 group-hover:scale-105 transition-transform duration-300">
                          {profile.name.charAt(0).toUpperCase()}
                        </div>
                        <div className={`absolute -bottom-1 -right-1 w-5 h-5 rounded-full border-2 border-white ${profile.is_active ? 'bg-success' : 'bg-gray-300'}`}></div>
                      </div>
                      <div>
                        <h3 className="text-xl font-bold text-gray-900 group-hover:text-primary transition-colors">{profile.name}</h3>
                        <p className="text-sm font-medium text-text-muted">{profile.age} ans</p>
                      </div>
                    </div>
                    
                    <div className="relative">
                      <button 
                        onClick={(e) => {
                          e.preventDefault();
                          e.stopPropagation();
                          setActiveMenuId(activeMenuId === profile.id ? null : profile.id);
                        }}
                        className="p-2 text-gray-400 hover:text-gray-700 hover:bg-gray-100 rounded-full transition-colors"
                      >
                        <MoreVertical className="w-5 h-5" />
                      </button>
                      
                      {activeMenuId === profile.id && (
                        <div className="absolute right-0 top-10 w-48 bg-white rounded-xl shadow-lg border border-gray-100 py-2 z-20 animate-fade-in">
                          <button 
                            onClick={(e) => handleEdit(e, profile)}
                            className="w-full flex items-center gap-3 px-4 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                          >
                            <Edit2 className="w-4 h-4" /> Modifier
                          </button>
                          <button 
                            onClick={(e) => handleDelete(e, profile.id)}
                            className="w-full flex items-center gap-3 px-4 py-2 text-left text-sm text-red-600 hover:bg-red-50 transition-colors"
                          >
                            <Trash2 className="w-4 h-4" /> Supprimer
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                  
                  {/* Fake stats for visual premium feel */}
                  <div className="grid grid-cols-2 gap-3 mb-6">
                    <div className="bg-gray-50/80 rounded-xl p-3 border border-gray-100">
                      <div className="flex items-center gap-1.5 text-text-muted mb-1">
                        <Clock className="w-3.5 h-3.5" />
                        <span className="text-xs font-medium uppercase tracking-wider">Aujourd'hui</span>
                      </div>
                      <div className="font-semibold text-gray-800">{profile.formatted_usage || "0h 00m"}</div>
                    </div>
                    <div className="bg-gray-50/80 rounded-xl p-3 border border-gray-100">
                      <div className="flex items-center gap-1.5 text-text-muted mb-1">
                        <ShieldAlert className={`w-3.5 h-3.5 ${profile.alert_count && profile.alert_count > 0 ? 'text-red-500' : ''}`} />
                        <span className="text-xs font-medium uppercase tracking-wider">Alertes</span>
                      </div>
                      <div className={`font-semibold ${profile.alert_count && profile.alert_count > 0 ? 'text-red-600' : 'text-gray-800'}`}>
                        {profile.alert_count && profile.alert_count > 0 ? `${profile.alert_count} alerte${profile.alert_count > 1 ? 's' : ''}` : "Aucune"}
                      </div>
                    </div>
                  </div>
                  
                  <div className="flex justify-between items-center pt-4 border-t border-gray-100">
                    <div className="flex items-center gap-2">
                      <span className={`text-sm font-medium ${profile.is_active ? 'text-success' : 'text-gray-400'}`}>
                        {profile.is_active ? 'Appareil actif' : 'Hors ligne'}
                      </span>
                    </div>
                    <div className="w-8 h-8 rounded-full bg-primary/5 flex items-center justify-center text-primary group-hover:bg-primary group-hover:text-white transition-colors">
                      <ChevronRight className="w-4 h-4" />
                    </div>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </main>

      <ProfileModal 
        isOpen={isModalOpen}
        onClose={() => { setIsModalOpen(false); setEditingProfile(null); }}
        onSuccess={loadData}
        profile={editingProfile}
      />
    </div>
  );
}
