"use client";

import { use } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import useSWR from "swr";
import { fetchAPI, logout } from "@/lib/api";
import { ArrowLeft, Clock, Moon, ShieldAlert, Smartphone, Activity, Trash2, CheckCircle2, Globe, Plus, X } from "lucide-react";
import { useState, useEffect } from "react";
import { Skeleton, CardSkeleton } from "@/components/Skeleton";

// Types
type Profile = { id: number; name: string; age: number; is_active: boolean; is_locked: boolean; };
type TimeRule = { id: number; profile_id: number; rule_type: "DAILY_LIMIT" | "BEDTIME_BLOCK" | "APP_BLOCK"; max_minutes_per_day: number | null; start_time: string | null; end_time: string | null; blocked_apps?: string[]; is_active: boolean; };
type ActivityLog = { id: number; activity_type: string; description: string; created_at: string; };

export default function ProfileSettingsPage({ params }: { params: Promise<{ id: string }> }) {
  const unwrappedParams = use(params);
  const profileId = parseInt(unwrappedParams.id);
  const router = useRouter();

  const [error, setError] = useState("");
  const [successMsg, setSuccessMsg] = useState("");
  
  const [showPairingModal, setShowPairingModal] = useState(false);
  const [pairingCode, setPairingCode] = useState<string | null>(null);
  const [pairingCodeExpiresAt, setPairingCodeExpiresAt] = useState<string | null>(null);
  const [isGeneratingCode, setIsGeneratingCode] = useState(false);
  const [timeLeft, setTimeLeft] = useState<string>("");

  const showSuccess = (msg: string) => { setSuccessMsg(msg); setTimeout(() => setSuccessMsg(""), 3000); };
  const showError = (msg: string) => { setError(msg); setTimeout(() => setError(""), 5000); };

  // Data fetching in parallel with SWR
  const { data: profiles, error: profilesError, mutate: mutateProfiles } = useSWR<Profile[]>("/profiles/", fetchAPI, { 
    onError: (err) => {
      if (err.message.includes("Non autorisé") || err.message.includes("credentials")) {
        logout();
        router.push("/login");
      }
    }
  });
  
  const { data: rules, mutate: mutateRules } = useSWR<TimeRule[]>(`/profiles/${profileId}/rules`, fetchAPI);
  const { data: logsData } = useSWR(`/profiles/${profileId}/logs`, fetchAPI);
  const { data: weeklyUsage } = useSWR<any[]>(`/profiles/${profileId}/weekly-usage`, fetchAPI);
  const { data: appUsage } = useSWR<any[]>(`/profiles/${profileId}/app-usage-detail`, fetchAPI);
  const { data: explicitLogs } = useSWR<any[]>(`/profiles/${profileId}/explicit-search-logs`, fetchAPI);
  const { data: filterData, mutate: mutateFilterData } = useSWR(`/filtering/profiles/${profileId}/rules`, fetchAPI);

  const profile = profiles?.find((p) => p.id === profileId);
  const logs: ActivityLog[] = logsData?.items || [];
  const strictWebFilter = filterData?.strict_mode ?? true;
  const webRules = filterData?.rules || [];

  const isLoadingProfile = !profiles && !profilesError;

  const handleToggleLock = async () => {
    if (!profile) return;
    const newStatus = !profile.is_locked;
    
    // Optimistic Update
    mutateProfiles(
      profiles?.map(p => p.id === profileId ? { ...p, is_locked: newStatus } : p),
      false
    );
    
    try {
      await fetchAPI(`/profiles/${profileId}/lock`, {
        method: "PUT",
        body: JSON.stringify({ is_locked: newStatus }),
      });
      showSuccess(newStatus ? "Appareil bloqué." : "Appareil débloqué.");
      mutateProfiles();
    } catch (err: any) {
      showError(err.message || "Erreur lors du verrouillage");
      mutateProfiles(); // rollback
    }
  };

  const generatePairingCode = async () => {
    try {
      setIsGeneratingCode(true);
      const data = await fetchAPI(`/profiles/${profileId}/pairing-code`, { method: "POST" });
      setPairingCode(data.pairing_code);
      setPairingCodeExpiresAt(data.expires_at);
    } catch (err: any) {
      showError(err.message || "Erreur lors de la génération du code");
    } finally {
      setIsGeneratingCode(false);
    }
  };

  // Countdown timer for pairing code
  useEffect(() => {
    if (!pairingCodeExpiresAt || !showPairingModal) return;
    
    const interval = setInterval(() => {
      const now = new Date().getTime();
      const expires = new Date(pairingCodeExpiresAt).getTime();
      const distance = expires - now;
      
      if (distance < 0) {
        clearInterval(interval);
        setTimeLeft("Expiré");
      } else {
        const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
        const seconds = Math.floor((distance % (1000 * 60)) / 1000);
        setTimeLeft(`${minutes}m ${seconds}s`);
      }
    }, 1000);
    
    return () => clearInterval(interval);
  }, [pairingCodeExpiresAt, showPairingModal]);

  const handleSaveDailyLimit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    const minutes = formData.get("minutes") ? parseInt(formData.get("minutes") as string) : null;
    if (!minutes || minutes < 1) return;

    try {
      const existingRule = rules?.find(r => r.rule_type === "DAILY_LIMIT");
      if (existingRule) {
        await fetchAPI(`/profiles/${profileId}/rules/${existingRule.id}`, { method: "PUT", body: JSON.stringify({ max_minutes_per_day: minutes, is_active: true }) });
      } else {
        await fetchAPI(`/profiles/${profileId}/rules`, { method: "POST", body: JSON.stringify({ rule_type: "DAILY_LIMIT", max_minutes_per_day: minutes, is_active: true }) });
      }
      mutateRules();
      showSuccess("Limite quotidienne enregistrée.");
    } catch (err: any) { showError(err.message); }
  };

  const handleSaveBedtime = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    const startTime = formData.get("start_time") as string;
    const endTime = formData.get("end_time") as string;
    if (!startTime || !endTime) return;

    const startStr = startTime.length === 5 ? `${startTime}:00` : startTime;
    const endStr = endTime.length === 5 ? `${endTime}:00` : endTime;

    try {
      const existingRule = rules?.find(r => r.rule_type === "BEDTIME_BLOCK");
      if (existingRule) {
        await fetchAPI(`/profiles/${profileId}/rules/${existingRule.id}`, { method: "PUT", body: JSON.stringify({ start_time: startStr, end_time: endStr, is_active: true }) });
      } else {
        await fetchAPI(`/profiles/${profileId}/rules`, { method: "POST", body: JSON.stringify({ rule_type: "BEDTIME_BLOCK", start_time: startStr, end_time: endStr, is_active: true }) });
      }
      mutateRules();
      showSuccess("Horaires de couvre-feu enregistrés.");
    } catch (err: any) { showError(err.message); }
  };

  const deleteRule = async (ruleId: number) => {
    if (!confirm("Voulez-vous vraiment supprimer cette règle ?")) return;
    try {
      await fetchAPI(`/profiles/${profileId}/rules/${ruleId}`, { method: "DELETE" });
      mutateRules();
      showSuccess("Règle supprimée.");
    } catch (err: any) { showError(err.message); }
  };

  const handleToggleAppBlock = async (packageName: string, isBlocked: boolean) => {
    try {
      const existingRule = rules?.find(r => r.rule_type === "APP_BLOCK");
      let newBlockedApps = existingRule && existingRule.blocked_apps ? [...existingRule.blocked_apps] : [];
      
      if (isBlocked && !newBlockedApps.includes(packageName)) newBlockedApps.push(packageName);
      else if (!isBlocked) newBlockedApps = newBlockedApps.filter(p => p !== packageName);

      // Optimistic update
      const optimisticRules = rules?.map(r => 
        r.rule_type === "APP_BLOCK" ? { ...r, blocked_apps: newBlockedApps } : r
      ) || [];
      if (!existingRule) optimisticRules.push({ id: 999, profile_id: profileId, rule_type: "APP_BLOCK", max_minutes_per_day: null, start_time: null, end_time: null, blocked_apps: newBlockedApps, is_active: true });
      mutateRules(optimisticRules, false);

      if (existingRule) {
        await fetchAPI(`/profiles/${profileId}/rules/${existingRule.id}`, { method: "PUT", body: JSON.stringify({ blocked_apps: newBlockedApps, is_active: true }) });
      } else {
        await fetchAPI(`/profiles/${profileId}/rules`, { method: "POST", body: JSON.stringify({ rule_type: "APP_BLOCK", blocked_apps: newBlockedApps, is_active: true }) });
      }
      
      mutateRules();
      showSuccess(isBlocked ? "Application bloquée." : "Application débloquée.");
    } catch (err: any) { showError(err.message); mutateRules(); }
  };

  const handleDeleteWebRule = async (ruleId: number) => {
    if (!confirm("Supprimer cette règle ?")) return;
    try {
      await fetchAPI(`/filtering/profiles/${profileId}/rules/${ruleId}`, { method: "DELETE" });
      mutateFilterData();
      showSuccess("Règle supprimée.");
    } catch (err: any) { showError(err.message); }
  };

  const handleAddWebRule = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    const domain = formData.get("domain") as string;
    if (!domain) return;

    try {
      await fetchAPI(`/filtering/profiles/${profileId}/rules`, { method: "POST", body: JSON.stringify({ url_pattern: domain, rule_type: "BLACKLIST" }) });
      mutateFilterData();
      showSuccess("Domaine bloqué avec succès.");
      (e.target as HTMLFormElement).reset();
    } catch (err: any) { showError(err.message); }
  };

  const handleToggleStrictMode = async () => {
    try {
      const newMode = !strictWebFilter;
      // Optimistic
      mutateFilterData({ ...filterData, strict_mode: newMode }, false);
      await fetchAPI(`/filtering/profiles/${profileId}/strict-mode`, { method: "PUT", body: JSON.stringify({ strict_mode: newMode }) });
      mutateFilterData();
      showSuccess(newMode ? "Filtrage strict activé." : "Filtrage strict désactivé.");
    } catch (err: any) { showError(err.message); mutateFilterData(); }
  };

  const dailyRule = rules?.find((r) => r.rule_type === "DAILY_LIMIT");
  const bedtimeRule = rules?.find((r) => r.rule_type === "BEDTIME_BLOCK");
  const appBlockRule = rules?.find(r => r.rule_type === "APP_BLOCK");
  const blockedApps = appBlockRule?.blocked_apps || [];

  if (isLoadingProfile) {
    return (
      <div className="min-h-screen bg-mesh pb-20 px-6 py-10 max-w-4xl mx-auto">
        <Skeleton className="h-32 w-full rounded-2xl mb-8" />
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2 space-y-6">
            <CardSkeleton />
            <CardSkeleton />
            <CardSkeleton />
          </div>
          <div className="lg:col-span-1">
            <Skeleton className="h-[500px] w-full rounded-2xl" />
          </div>
        </div>
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="min-h-screen bg-mesh p-10 flex flex-col items-center justify-center">
        <div className="glass p-8 rounded-2xl text-center">
          <ShieldAlert className="w-12 h-12 text-danger mx-auto mb-4" />
          <h2 className="text-xl font-bold text-gray-900 mb-2">Profil introuvable</h2>
          <Link href="/dashboard" className="text-primary hover:text-primary-dark font-medium transition-colors">&larr; Retour au Dashboard</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-mesh pb-20">
      <nav className="sticky top-0 z-50 glass border-b border-white/20 px-6 py-4">
        <div className="max-w-6xl mx-auto flex justify-between items-center w-full">
          <div className="flex items-center gap-4">
            <Link href="/dashboard" className="flex items-center gap-2 text-text-muted hover:text-primary transition-colors font-medium">
              <ArrowLeft className="w-5 h-5" /> <span>Retour</span>
            </Link>
            <div className="h-6 w-px bg-gray-300"></div>
            <h1 className="text-xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-gray-900 to-gray-700">Paramètres de {profile.name}</h1>
          </div>
          <div className="flex items-center gap-4">
            <Link href={`/dashboard/${profileId}/gamification`} className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-text-muted hover:text-primary hover:bg-white/50 rounded-lg transition-all">
              <span className="text-xl">🎮</span> <span className="hidden sm:inline">Gamification</span>
            </Link>
            <Link href="/dashboard/logs" className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-text-muted hover:text-primary hover:bg-white/50 rounded-lg transition-all">
              <Activity className="w-4 h-4" /> <span className="hidden sm:inline">Historique</span>
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
              <span className="bg-white/80 px-3 py-1 rounded-full text-sm font-medium text-text-muted border border-gray-200">{profile.age} ans</span>
              <span className={`px-3 py-1 rounded-full text-sm font-medium border ${profile.is_active ? 'bg-success/10 text-success border-success/20' : 'bg-gray-100 text-gray-500 border-gray-200'}`}>
                {profile.is_active ? 'Appareil actif' : 'Hors ligne'}
              </span>
              <button onClick={handleToggleLock} className={`px-4 py-1 rounded-full text-sm font-bold border transition-all shadow-sm ${profile.is_locked ? 'bg-success text-white border-success hover:bg-success/90' : 'bg-danger text-white border-danger hover:bg-danger/90'}`}>
                {profile.is_locked ? '🔒 Débloquer l\'appareil' : '🔓 Bloquer maintenant'}
              </button>
              <button 
                onClick={() => { setShowPairingModal(true); if (!pairingCode) generatePairingCode(); }} 
                className="px-4 py-1 rounded-full text-sm font-bold border transition-all shadow-sm bg-blue-600 text-white border-blue-600 hover:bg-blue-700"
              >
                📱 Lier un appareil
              </button>
            </div>
          </div>
        </div>

        {/* Notifications */}
        {error && <div className="bg-danger/10 border border-danger/20 text-danger p-4 rounded-xl mb-6 flex items-center gap-3 animate-fade-in"><ShieldAlert className="w-5 h-5 flex-shrink-0" /><p className="font-medium">{error}</p></div>}
        {successMsg && <div className="bg-success/10 border border-success/20 text-success p-4 rounded-xl mb-6 flex items-center gap-3 animate-fade-in"><CheckCircle2 className="w-5 h-5 flex-shrink-0" /><p className="font-medium">{successMsg}</p></div>}

        {/* Weekly Usage Chart */}
        {!weeklyUsage ? <Skeleton className="h-48 w-full rounded-2xl mb-8" /> : weeklyUsage.length > 0 && (
          <div className="glass p-6 rounded-2xl mb-8 border border-white/40 shadow-sm animate-fade-in delay-100">
            <h3 className="text-lg font-bold text-gray-900 mb-6 flex items-center gap-2"><Activity className="w-5 h-5 text-primary" /> Temps d'écran (7 derniers jours)</h3>
            <div className="h-48 flex items-end justify-between gap-2 sm:gap-4 mt-4">
              {weeklyUsage.map((dayData, idx) => {
                const maxMins = Math.max(...weeklyUsage.map(d => d.minutes), 60);
                const heightPercent = Math.min(100, (dayData.minutes / maxMins) * 100);
                const formattedTime = `${Math.floor(dayData.minutes / 60)}h${dayData.minutes % 60}m`;
                return (
                  <div key={idx} className="flex flex-col items-center justify-end w-full h-full group">
                    <div className="opacity-0 group-hover:opacity-100 transition-opacity bg-gray-900 text-white text-xs py-1 px-2 rounded mb-2 whitespace-nowrap z-10">{formattedTime}</div>
                    <div className="w-full sm:w-12 bg-gradient-to-t from-primary-dark to-primary rounded-t-md transition-all duration-500 hover:brightness-110" style={{ height: `${Math.max(heightPercent, 2)}%` }}></div>
                    <span className="text-xs text-text-muted mt-2 font-medium">{dayData.day}</span>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2 space-y-6">
            <h3 className="text-xl font-bold text-gray-900 mb-2">Règles de Temps d'Écran</h3>

            {!rules ? <CardSkeleton /> : (
              <div className="glass bg-white/80 p-6 rounded-2xl shadow-sm border border-white/50 transition-all hover:shadow-md">
                <div className="flex justify-between items-start mb-6">
                  <div className="flex gap-4">
                    <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center text-primary"><Clock className="w-6 h-6" /></div>
                    <div>
                      <h4 className="text-lg font-bold text-gray-900">Limite Quotidienne</h4>
                      <p className="text-sm text-text-muted mt-1">Définissez un temps maximum d'utilisation par jour.</p>
                    </div>
                  </div>
                  {dailyRule && <button onClick={() => deleteRule(dailyRule.id)} className="text-gray-400 hover:text-danger hover:bg-danger/10 p-2 rounded-lg transition-colors"><Trash2 className="w-5 h-5" /></button>}
                </div>
                <form onSubmit={handleSaveDailyLimit} className="flex items-end gap-4 bg-gray-50/50 p-4 rounded-xl border border-gray-100">
                  <div className="flex-1">
                    <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">Temps alloué (minutes)</label>
                    <input type="number" name="minutes" min="1" max="1440" defaultValue={dailyRule?.max_minutes_per_day || ""} className="w-full px-4 py-2.5 bg-white border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 text-gray-900 font-medium" placeholder="Ex: 120 pour 2 heures" required />
                  </div>
                  <button type="submit" className="bg-gradient-to-r from-primary to-primary-dark hover:from-primary-dark text-white px-6 py-2.5 rounded-lg font-medium shadow-sm">Enregistrer</button>
                </form>
              </div>
            )}

            {!rules ? <CardSkeleton /> : (
              <div className="glass bg-white/80 p-6 rounded-2xl shadow-sm border border-white/50 transition-all hover:shadow-md">
                <div className="flex justify-between items-start mb-6">
                  <div className="flex gap-4">
                    <div className="w-12 h-12 rounded-xl bg-warning/10 flex items-center justify-center text-warning"><Moon className="w-6 h-6" /></div>
                    <div>
                      <h4 className="text-lg font-bold text-gray-900">Couvre-feu (Nuit)</h4>
                      <p className="text-sm text-text-muted mt-1">Bloquez l'appareil pendant les heures de sommeil.</p>
                    </div>
                  </div>
                  {bedtimeRule && <button onClick={() => deleteRule(bedtimeRule.id)} className="text-gray-400 hover:text-danger hover:bg-danger/10 p-2 rounded-lg transition-colors"><Trash2 className="w-5 h-5" /></button>}
                </div>
                <form onSubmit={handleSaveBedtime} className="bg-gray-50/50 p-4 rounded-xl border border-gray-100">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">Heure de coucher</label>
                      <input type="time" name="start_time" defaultValue={bedtimeRule?.start_time?.substring(0, 5) || "21:00"} className="w-full px-4 py-2.5 bg-white border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 text-gray-900 font-medium" required />
                    </div>
                    <div>
                      <label className="block text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">Heure de réveil</label>
                      <input type="time" name="end_time" defaultValue={bedtimeRule?.end_time?.substring(0, 5) || "07:00"} className="w-full px-4 py-2.5 bg-white border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 text-gray-900 font-medium" required />
                    </div>
                  </div>
                  <div className="mt-4 flex justify-end">
                    <button type="submit" className="bg-gradient-to-r from-primary to-primary-dark hover:from-primary-dark text-white px-6 py-2.5 rounded-lg font-medium shadow-sm">Enregistrer</button>
                  </div>
                </form>
              </div>
            )}

            {!filterData ? <CardSkeleton /> : (
              <div className="glass bg-white/80 p-6 rounded-2xl shadow-sm border border-white/50 transition-all hover:shadow-md mt-6">
                <div className="flex justify-between items-start mb-6">
                  <div className="flex gap-4">
                    <div className="w-12 h-12 rounded-xl bg-blue-100 flex items-center justify-center text-blue-600"><Globe className="w-6 h-6" /></div>
                    <div>
                      <h4 className="text-lg font-bold text-gray-900">Filtrage Web</h4>
                      <p className="text-sm text-text-muted mt-1">Gérez l'accès aux sites web pour ce profil.</p>
                    </div>
                  </div>
                </div>
                <div className="bg-gray-50/50 p-4 rounded-xl border border-gray-100 mb-6 flex justify-between items-center">
                  <div>
                    <h5 className="font-bold text-gray-900">Blocage Strict Automatique</h5>
                    <p className="text-xs text-gray-500">Bloque automatiquement les sites pour adultes, jeux d'argent et contenus violents.</p>
                  </div>
                  <button onClick={handleToggleStrictMode} className={`flex-shrink-0 relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 ${strictWebFilter ? 'bg-success' : 'bg-gray-300'}`}>
                    <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${strictWebFilter ? 'translate-x-6' : 'translate-x-1'}`} />
                  </button>
                </div>
                <div className="mt-4">
                  <h5 className="font-bold text-gray-900 mb-2">Liste Noire Personnalisée</h5>
                  <form onSubmit={handleAddWebRule} className="flex gap-2 mb-4">
                    <input name="domain" placeholder="ex: facebook.com" className="flex-1 px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 text-sm" required />
                    <button type="submit" className="bg-gray-900 hover:bg-black text-white px-4 py-2 rounded-lg text-sm font-medium transition-all flex items-center gap-2"><Plus className="w-4 h-4" /> Bloquer</button>
                  </form>
                  <div className="space-y-2">
                    {webRules.length === 0 ? <p className="text-sm text-gray-500 italic">Aucun domaine bloqué manuellement.</p> : webRules.filter((r: any) => r.rule_type === "BLACKLIST").map((rule: any) => (
                      <div key={rule.id} className="flex justify-between items-center bg-white border border-gray-100 p-3 rounded-lg">
                        <span className="text-sm font-medium text-gray-900">{rule.url_pattern}</span>
                        <button onClick={() => handleDeleteWebRule(rule.id)} className="text-gray-400 hover:text-danger"><Trash2 className="w-4 h-4" /></button>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {appUsage && appUsage.length > 0 && (
              <div className="glass bg-white/80 p-6 rounded-2xl shadow-sm border border-white/50 transition-all hover:shadow-md mt-6">
                <h4 className="text-lg font-bold text-gray-900 mb-4">Utilisation détaillée par application (Aujourd'hui)</h4>
                <div className="space-y-4">
                  {appUsage.map((app, idx) => {
                    const maxMins = Math.max(...appUsage.map(a => a.minutes_today), 60);
                    const percent = Math.min(100, (app.minutes_today / maxMins) * 100);
                    const isBlocked = blockedApps.includes(app.package_name);
                    return (
                      <div key={idx} className="flex items-center gap-4">
                        <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center text-xl">{app.icon}</div>
                        <div className="flex-1">
                          <div className="flex justify-between mb-1">
                            <span className="font-semibold text-sm text-gray-900">{app.app_name}</span>
                            <span className="font-bold text-sm text-primary">{Math.floor(app.minutes_today / 60)}h {(app.minutes_today % 60).toString().padStart(2, '0')}m</span>
                          </div>
                          <div className="w-full bg-gray-100 rounded-full h-2"><div className={`h-2 rounded-full ${isBlocked ? 'bg-danger' : 'bg-primary'}`} style={{ width: `${percent}%` }}></div></div>
                        </div>
                        <button onClick={() => handleToggleAppBlock(app.package_name, !isBlocked)} className={`flex-shrink-0 relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 ${isBlocked ? 'bg-danger' : 'bg-success'}`} title={isBlocked ? "Débloquer" : "Bloquer"}>
                          <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${isBlocked ? 'translate-x-1' : 'translate-x-6'}`} />
                        </button>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
            
            {explicitLogs && explicitLogs.length > 0 && (
              <div className="glass bg-white/80 p-6 rounded-2xl shadow-sm border border-white/50 transition-all hover:shadow-md mt-6 border-red-100">
                <h4 className="text-lg font-bold text-danger mb-4 flex items-center gap-2"><ShieldAlert className="w-5 h-5" /> Recherches explicites bloquées</h4>
                <div className="space-y-3">
                  {explicitLogs.map((log, idx) => (
                    <div key={idx} className="bg-red-50 p-3 rounded-lg border border-red-100 flex justify-between items-center">
                      <span className="text-sm font-semibold text-red-900">{log.description}</span>
                      <span className="text-xs text-red-700 font-medium">{new Date(log.created_at).toLocaleString('fr-FR', { day: '2-digit', month: 'short', hour: '2-digit', minute:'2-digit' })}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          <div className="lg:col-span-1">
            <h3 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2"><Activity className="w-5 h-5 text-primary" /> Activité Récente</h3>
            {!logsData ? <Skeleton className="h-[500px] w-full rounded-2xl" /> : (
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
                              <p className="text-xs font-medium text-text-muted ml-6">{new Date(log.created_at).toLocaleString('fr-FR', { day: '2-digit', month: 'short', hour: '2-digit', minute:'2-digit' })}</p>
                            </div>
                          </li>
                        ))}
                      </ul>
                      <div className="pt-2 border-t border-gray-100">
                        <Link href="/dashboard/logs" className="block text-center text-sm font-bold text-primary hover:text-primary-dark transition-colors py-2">Voir tout l'historique →</Link>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>
      </main>

      {/* Pairing Modal */}
      {showPairingModal && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-gray-900/40 backdrop-blur-sm p-4 animate-fade-in">
          <div className="bg-white rounded-3xl shadow-xl w-full max-w-md overflow-hidden flex flex-col">
            <div className="p-6 border-b border-gray-100 flex justify-between items-center bg-gray-50/50">
              <h2 className="text-xl font-bold text-gray-900">Lier un appareil</h2>
              <button onClick={() => setShowPairingModal(false)} className="text-gray-400 hover:text-gray-600 transition-colors p-2 rounded-full hover:bg-gray-100">
                <X className="w-5 h-5" />
              </button>
            </div>
            
            <div className="p-8 flex flex-col items-center justify-center text-center">
              <div className="w-16 h-16 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center mb-6">
                <Smartphone className="w-8 h-8" />
              </div>
              
              <h3 className="text-lg font-bold text-gray-900 mb-2">Code de liaison</h3>
              <p className="text-sm text-gray-500 mb-6">
                Ouvrez l'application FamilyGuard sur l'appareil de {profile.name} et entrez ce code pour le lier à ce profil.
              </p>
              
              {isGeneratingCode ? (
                <div className="h-24 flex items-center justify-center">
                  <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin"></div>
                </div>
              ) : pairingCode ? (
                <div className="w-full">
                  <div className="bg-gray-100 py-4 px-6 rounded-2xl mb-4 border border-gray-200">
                    <span className="text-4xl font-black tracking-[0.5em] text-gray-900 ml-[0.5em]">
                      {pairingCode}
                    </span>
                  </div>
                  {timeLeft === "Expiré" ? (
                    <div className="text-danger font-medium flex items-center justify-center gap-2">
                      <Clock className="w-4 h-4" /> Code expiré
                    </div>
                  ) : (
                    <div className="text-primary font-medium flex items-center justify-center gap-2">
                      <Clock className="w-4 h-4" /> Expire dans {timeLeft}
                    </div>
                  )}
                </div>
              ) : null}
            </div>
            
            <div className="p-6 border-t border-gray-100 bg-gray-50/50">
              <button 
                onClick={generatePairingCode} 
                disabled={isGeneratingCode}
                className="w-full bg-white border-2 border-gray-200 text-gray-700 hover:border-primary hover:text-primary font-bold py-3 rounded-xl transition-all"
              >
                Générer un nouveau code
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
