"use client";

import { useEffect, useState, use } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { fetchAPI, logout } from "@/lib/api";
import { ArrowLeft, Clock, Moon, ShieldAlert, Smartphone, Activity, Trash2, CheckCircle2 } from "lucide-react";

type Profile = {
  id: number;
  name: string;
  age: number;
  is_active: boolean;
  is_locked: boolean;
};

type TimeRule = {
  id: number;
  profile_id: number;
  rule_type: "DAILY_LIMIT" | "BEDTIME_BLOCK";
  max_minutes_per_day: number | null;
  start_time: string | null;
  end_time: string | null;
  is_active: boolean;
};

type ActivityLog = {
  id: number;
  activity_type: string;
  description: string;
  created_at: string;
};

export default function ProfileSettingsPage({ params }: { params: Promise<{ id: string }> }) {
  const unwrappedParams = use(params);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [rules, setRules] = useState<TimeRule[]>([]);
  const [logs, setLogs] = useState<ActivityLog[]>([]);
  const [weeklyUsage, setWeeklyUsage] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [successMsg, setSuccessMsg] = useState("");
  const router = useRouter();

  const profileId = parseInt(unwrappedParams.id);

  useEffect(() => {
    const loadData = async () => {
      try {
        const profiles: Profile[] = await fetchAPI("/profiles/");
        const currentProfile = profiles.find((p) => p.id === profileId);
        
        if (!currentProfile) {
          setError("Profil introuvable");
          setLoading(false);
          return;
        }
        
        setProfile(currentProfile);

        const fetchedRules = await fetchAPI(`/profiles/${profileId}/rules`);
        setRules(fetchedRules);

        try {
          const fetchedLogs = await fetchAPI(`/profiles/${profileId}/logs`);
          setLogs(fetchedLogs.items || []);
        } catch (logErr) {
          console.error("Erreur chargement logs:", logErr);
        }

        try {
          const usage = await fetchAPI(`/profiles/${profileId}/weekly-usage`);
          setWeeklyUsage(usage);
        } catch (usageErr) {
          console.error("Erreur chargement weekly usage:", usageErr);
        }
        
      } catch (err: any) {
        if (err.message.includes("Non autorisé") || err.message.includes("credentials")) {
          logout();
          router.push("/login");
        } else {
          setError(err.message || "Erreur de chargement");
        }
      } finally {
        setLoading(false);
      }
    };
    loadData();
  }, [profileId, router]);

  const handleToggleLock = async () => {
    if (!profile) return;
    try {
      const newStatus = !profile.is_locked;
      await fetchAPI(`/profiles/${profileId}/lock`, {
        method: "PUT",
        body: JSON.stringify({ is_locked: newStatus }),
      });
      setProfile({ ...profile, is_locked: newStatus });
      setSuccessMsg(newStatus ? "Appareil bloqué." : "Appareil débloqué.");
      setTimeout(() => setSuccessMsg(""), 3000);
    } catch (err: any) {
      setError(err.message || "Erreur lors du verrouillage");
    }
  };

  const handleSaveDailyLimit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setSuccessMsg("");
    setError("");
    const formData = new FormData(e.currentTarget);
    const minutes = formData.get("minutes") ? parseInt(formData.get("minutes") as string) : null;
    
    if (!minutes || minutes < 1) return;

    try {
      const existingRule = rules.find(r => r.rule_type === "DAILY_LIMIT");
      if (existingRule) {
        await fetchAPI(`/profiles/${profileId}/rules/${existingRule.id}`, {
          method: "PUT",
          body: JSON.stringify({ max_minutes_per_day: minutes, is_active: true }),
        });
      } else {
        await fetchAPI(`/profiles/${profileId}/rules`, {
          method: "POST",
          body: JSON.stringify({ rule_type: "DAILY_LIMIT", max_minutes_per_day: minutes, is_active: true }),
        });
      }
      
      const updatedRules = await fetchAPI(`/profiles/${profileId}/rules`);
      setRules(updatedRules);
      setSuccessMsg("Limite quotidienne enregistrée avec succès.");
      setTimeout(() => setSuccessMsg(""), 3000);
    } catch (err: any) {
      setError(err.message || "Erreur lors de l'enregistrement");
    }
  };

  const handleSaveBedtime = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setSuccessMsg("");
    setError("");
    const formData = new FormData(e.currentTarget);
    const startTime = formData.get("start_time") as string;
    const endTime = formData.get("end_time") as string;
    
    if (!startTime || !endTime) return;

    const startStr = startTime.length === 5 ? `${startTime}:00` : startTime;
    const endStr = endTime.length === 5 ? `${endTime}:00` : endTime;

    try {
      const existingRule = rules.find(r => r.rule_type === "BEDTIME_BLOCK");
      if (existingRule) {
        await fetchAPI(`/profiles/${profileId}/rules/${existingRule.id}`, {
          method: "PUT",
          body: JSON.stringify({ start_time: startStr, end_time: endStr, is_active: true }),
        });
      } else {
        await fetchAPI(`/profiles/${profileId}/rules`, {
          method: "POST",
          body: JSON.stringify({ rule_type: "BEDTIME_BLOCK", start_time: startStr, end_time: endStr, is_active: true }),
        });
      }
      
      const updatedRules = await fetchAPI(`/profiles/${profileId}/rules`);
      setRules(updatedRules);
      setSuccessMsg("Horaires de couvre-feu enregistrés.");
      setTimeout(() => setSuccessMsg(""), 3000);
    } catch (err: any) {
      setError(err.message || "Erreur lors de l'enregistrement");
    }
  };

  const deleteRule = async (ruleId: number) => {
    if (!confirm("Voulez-vous vraiment supprimer cette règle ?")) return;
    try {
      await fetchAPI(`/profiles/${profileId}/rules/${ruleId}`, { method: "DELETE" });
      setRules(rules.filter(r => r.id !== ruleId));
      setSuccessMsg("Règle supprimée.");
      setTimeout(() => setSuccessMsg(""), 3000);
    } catch (err: any) {
      setError(err.message || "Erreur de suppression");
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-mesh flex items-center justify-center">
        <div className="relative w-16 h-16">
          <div className="absolute inset-0 rounded-full border-t-2 border-primary animate-spin"></div>
          <div className="absolute inset-2 rounded-full border-r-2 border-primary-light animate-spin" style={{ animationDirection: 'reverse', animationDuration: '1.5s' }}></div>
        </div>
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="min-h-screen bg-mesh p-10 flex flex-col items-center justify-center">
        <div className="glass p-8 rounded-2xl text-center">
          <ShieldAlert className="w-12 h-12 text-danger mx-auto mb-4" />
          <h2 className="text-xl font-bold text-gray-900 mb-2">{error}</h2>
          <Link href="/dashboard" className="text-primary hover:text-primary-dark font-medium transition-colors">
            &larr; Retour au Dashboard
          </Link>
        </div>
      </div>
    );
  }

  const dailyRule = rules.find(r => r.rule_type === "DAILY_LIMIT");
  const bedtimeRule = rules.find(r => r.rule_type === "BEDTIME_BLOCK");

  return (
    <div className="min-h-screen bg-mesh pb-20">
      {/* Navigation */}
      <nav className="sticky top-0 z-50 glass border-b border-white/20 px-6 py-4">
        <div className="max-w-6xl mx-auto flex justify-between items-center w-full">
          <div className="flex items-center gap-4">
            <Link href="/dashboard" className="flex items-center gap-2 text-text-muted hover:text-primary transition-colors font-medium">
              <ArrowLeft className="w-5 h-5" />
              <span>Retour</span>
            </Link>
            <div className="h-6 w-px bg-gray-300"></div>
            <h1 className="text-xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-gray-900 to-gray-700">
              Paramètres de {profile.name}
            </h1>
          </div>
          <div className="flex items-center gap-4">
            <Link href="/dashboard/logs" className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-text-muted hover:text-primary hover:bg-white/50 rounded-lg transition-all">
              <Activity className="w-4 h-4" />
              <span className="hidden sm:inline">Historique</span>
            </Link>
          </div>
        </div>
      </nav>

      <main className="max-w-4xl mx-auto px-6 py-10 animate-slide-up">
        
        {/* Profile Header */}
        <div className="glass bg-white/60 p-8 rounded-2xl shadow-sm border border-white/50 flex flex-col sm:flex-row items-center sm:items-start gap-6 mb-8 relative overflow-hidden">
          <div className="absolute top-0 right-0 w-64 h-64 bg-primary/5 rounded-full filter blur-3xl -translate-y-1/2 translate-x-1/3"></div>
          
          <div className="relative">
            <div className="w-24 h-24 bg-gradient-to-br from-primary to-primary-dark text-white rounded-3xl flex items-center justify-center text-4xl font-bold shadow-lg shadow-primary/30">
              {profile.name.charAt(0).toUpperCase()}
            </div>
            <div className={`absolute -bottom-2 -right-2 w-6 h-6 rounded-full border-4 border-white ${profile.is_active ? 'bg-success' : 'bg-gray-300'}`}></div>
          </div>
          
          <div className="text-center sm:text-left z-10 pt-2">
            <h2 className="text-3xl font-bold text-gray-900">{profile.name}</h2>
            <div className="flex flex-wrap items-center justify-center sm:justify-start gap-3 mt-4">
              <span className="bg-white/80 px-3 py-1 rounded-full text-sm font-medium text-text-muted border border-gray-200">
                {profile.age} ans
              </span>
              <span className={`px-3 py-1 rounded-full text-sm font-medium border ${profile.is_active ? 'bg-success/10 text-success border-success/20' : 'bg-gray-100 text-gray-500 border-gray-200'}`}>
                {profile.is_active ? 'Appareil actif' : 'Hors ligne'}
              </span>
              <button 
                onClick={handleToggleLock}
                className={`px-4 py-1 rounded-full text-sm font-bold border transition-all shadow-sm ${profile.is_locked ? 'bg-success text-white border-success hover:bg-success/90' : 'bg-danger text-white border-danger hover:bg-danger/90'}`}
              >
                {profile.is_locked ? '🔒 Débloquer l\'appareil' : '🔓 Bloquer maintenant'}
              </button>
            </div>
          </div>
        </div>

        {/* Notifications */}
        {error && (
          <div className="bg-danger/10 border border-danger/20 text-danger p-4 rounded-xl mb-6 flex items-center gap-3 animate-fade-in">
            <ShieldAlert className="w-5 h-5 flex-shrink-0" />
            <p className="font-medium">{error}</p>
          </div>
        )}
        {successMsg && (
          <div className="bg-success/10 border border-success/20 text-success p-4 rounded-xl mb-6 flex items-center gap-3 animate-fade-in">
            <CheckCircle2 className="w-5 h-5 flex-shrink-0" />
            <p className="font-medium">{successMsg}</p>
          </div>
        )}

        {/* Weekly Usage Chart */}
        {weeklyUsage.length > 0 && (
          <div className="glass p-6 rounded-2xl mb-8 border border-white/40 shadow-sm animate-fade-in delay-100">
            <h3 className="text-lg font-bold text-gray-900 mb-6 flex items-center gap-2">
              <Activity className="w-5 h-5 text-primary" /> Temps d'écran (7 derniers jours)
            </h3>
            <div className="h-48 flex items-end justify-between gap-2 sm:gap-4 mt-4">
              {weeklyUsage.map((dayData, idx) => {
                // Calculate height percentage based on a max of e.g. 4 hours (240 mins) to avoid huge bars
                const maxMins = Math.max(...weeklyUsage.map(d => d.minutes), 60);
                const heightPercent = Math.min(100, (dayData.minutes / maxMins) * 100);
                const formattedTime = `${Math.floor(dayData.minutes / 60)}h${dayData.minutes % 60}m`;
                
                return (
                  <div key={idx} className="flex flex-col items-center justify-end w-full h-full group">
                    {/* Tooltip on hover */}
                    <div className="opacity-0 group-hover:opacity-100 transition-opacity bg-gray-900 text-white text-xs py-1 px-2 rounded mb-2 whitespace-nowrap z-10">
                      {formattedTime}
                    </div>
                    {/* Bar */}
                    <div 
                      className="w-full sm:w-12 bg-gradient-to-t from-primary-dark to-primary rounded-t-md transition-all duration-500 hover:brightness-110" 
                      style={{ height: `${Math.max(heightPercent, 2)}%` }}
                    ></div>
                    {/* Label */}
                    <span className="text-xs text-text-muted mt-2 font-medium">{dayData.day}</span>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          
          {/* Main settings column */}
          <div className="lg:col-span-2 space-y-6">
            <h3 className="text-xl font-bold text-gray-900 mb-2">Règles de Temps d'Écran</h3>

            {/* Daily Limit Card */}
            <div className="glass bg-white/80 p-6 rounded-2xl shadow-sm border border-white/50 transition-all hover:shadow-md">
              <div className="flex justify-between items-start mb-6">
                <div className="flex gap-4">
                  <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center text-primary">
                    <Clock className="w-6 h-6" />
                  </div>
                  <div>
                    <h4 className="text-lg font-bold text-gray-900">Limite Quotidienne</h4>
                    <p className="text-sm text-text-muted mt-1">Définissez un temps maximum d'utilisation par jour.</p>
                  </div>
                </div>
                {dailyRule && (
                  <button onClick={() => deleteRule(dailyRule.id)} className="text-gray-400 hover:text-danger hover:bg-danger/10 p-2 rounded-lg transition-colors" title="Supprimer la règle">
                    <Trash2 className="w-5 h-5" />
                  </button>
                )}
              </div>
              
              <form onSubmit={handleSaveDailyLimit} className="flex items-end gap-4 bg-gray-50/50 p-4 rounded-xl border border-gray-100">
                <div className="flex-1">
                  <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">Temps alloué (minutes)</label>
                  <input 
                    type="number" 
                    name="minutes"
                    min="1" max="1440"
                    defaultValue={dailyRule?.max_minutes_per_day || ""}
                    className="w-full px-4 py-2.5 bg-white border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 text-gray-900 font-medium transition-shadow"
                    placeholder="Ex: 120 pour 2 heures"
                    required
                  />
                </div>
                <button type="submit" className="bg-gradient-to-r from-primary to-primary-dark hover:from-primary-dark hover:to-[#173587] text-white px-6 py-2.5 rounded-lg font-medium transition-all shadow-sm shadow-primary/20">
                  Enregistrer
                </button>
              </form>
            </div>

            {/* Bedtime Block Card */}
            <div className="glass bg-white/80 p-6 rounded-2xl shadow-sm border border-white/50 transition-all hover:shadow-md">
              <div className="flex justify-between items-start mb-6">
                <div className="flex gap-4">
                  <div className="w-12 h-12 rounded-xl bg-warning/10 flex items-center justify-center text-warning">
                    <Moon className="w-6 h-6" />
                  </div>
                  <div>
                    <h4 className="text-lg font-bold text-gray-900">Couvre-feu (Nuit)</h4>
                    <p className="text-sm text-text-muted mt-1">Bloquez l'appareil pendant les heures de sommeil.</p>
                  </div>
                </div>
                {bedtimeRule && (
                  <button onClick={() => deleteRule(bedtimeRule.id)} className="text-gray-400 hover:text-danger hover:bg-danger/10 p-2 rounded-lg transition-colors" title="Supprimer la règle">
                    <Trash2 className="w-5 h-5" />
                  </button>
                )}
              </div>
              
              <form onSubmit={handleSaveBedtime} className="bg-gray-50/50 p-4 rounded-xl border border-gray-100">
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">Heure de coucher</label>
                    <input 
                      type="time" 
                      name="start_time"
                      defaultValue={bedtimeRule?.start_time?.substring(0, 5) || "21:00"}
                      className="w-full px-4 py-2.5 bg-white border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 text-gray-900 font-medium transition-shadow"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">Heure de réveil</label>
                    <input 
                      type="time" 
                      name="end_time"
                      defaultValue={bedtimeRule?.end_time?.substring(0, 5) || "07:00"}
                      className="w-full px-4 py-2.5 bg-white border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 text-gray-900 font-medium transition-shadow"
                      required
                    />
                  </div>
                </div>
                <div className="mt-4 flex justify-end">
                  <button type="submit" className="bg-gradient-to-r from-primary to-primary-dark hover:from-primary-dark hover:to-[#173587] text-white px-6 py-2.5 rounded-lg font-medium transition-all shadow-sm shadow-primary/20">
                    Enregistrer
                  </button>
                </div>
              </form>
            </div>
          </div>

          {/* Sidebar / Activity Feed */}
          <div className="lg:col-span-1">
            <h3 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
              <Activity className="w-5 h-5 text-primary" /> 
              Activité Récente
            </h3>
            
            <div className="glass bg-white/80 p-1 rounded-2xl shadow-sm border border-white/50 h-[500px] overflow-hidden flex flex-col">
              <div className="p-4 flex-1 overflow-y-auto overflow-x-hidden custom-scrollbar">
                {logs.length === 0 ? (
                  <div className="h-full flex flex-col items-center justify-center text-center opacity-60 p-4">
                    <Activity className="w-10 h-10 text-gray-400 mb-3" />
                    <p className="text-sm font-medium text-gray-500">Aucune activité récente pour le moment.</p>
                  </div>
                ) : (
                  <div className="space-y-4">
                    <ul className="space-y-4">
                      {logs.map((log) => (
                        <li key={log.id} className="relative pl-10 pb-4 border-l-2 border-gray-100 last:border-0 last:pb-0">
                          <div className={`absolute -left-[9px] top-0 w-4 h-4 rounded-full border-2 border-white shadow-sm ${
                            log.activity_type === 'SOS_TRIGGERED' ? 'bg-danger' :
                            log.activity_type === 'WEB_BLOCKED' ? 'bg-warning' :
                            log.activity_type === 'TIME_LIMIT_REACHED' ? 'bg-gray-500' : 'bg-primary'
                          }`}></div>
                          
                          <div className="bg-white p-3 rounded-xl border border-gray-100 shadow-sm">
                            <div className="flex items-start gap-2 mb-1">
                              {log.activity_type === 'SOS_TRIGGERED' && <ShieldAlert className="w-4 h-4 text-danger mt-0.5" />}
                              {log.activity_type === 'WEB_BLOCKED' && <ShieldAlert className="w-4 h-4 text-warning mt-0.5" />}
                              {log.activity_type === 'TIME_LIMIT_REACHED' && <Clock className="w-4 h-4 text-gray-500 mt-0.5" />}
                              {log.activity_type === 'APP_USED' && <Smartphone className="w-4 h-4 text-primary mt-0.5" />}
                              <p className="text-sm font-bold text-gray-900 leading-tight">{log.description}</p>
                            </div>
                            <p className="text-xs font-medium text-text-muted ml-6">
                              {new Date(log.created_at).toLocaleString('fr-FR', { 
                                day: '2-digit', month: 'short', hour: '2-digit', minute:'2-digit' 
                              })}
                            </p>
                          </div>
                        </li>
                      ))}
                    </ul>
                    <div className="pt-2 border-t border-gray-100">
                      <Link href="/dashboard/logs" className="block text-center text-sm font-bold text-primary hover:text-primary-dark transition-colors py-2">
                        Voir tout l'historique →
                      </Link>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>

        </div>
      </main>
    </div>
  );
}
