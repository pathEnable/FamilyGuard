"use client";

import { useEffect, useState } from "react";
import { use } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { ArrowLeft, ShieldAlert, Trophy, Star, Target, CheckCircle2, Gift, Plus, Trash2 } from "lucide-react";
import { fetchAPI } from "@/lib/api";

interface Profile {
  id: number;
  name: string;
  age: number;
  is_active: boolean;
  is_locked: boolean;
}

interface GamificationSummary {
  total_points: number;
  current_streak: number;
  best_streak: number;
  avatar_level: number;
  recent_badges: any[];
}

interface Reward {
  id: number;
  title: string;
  description: string;
  bonus_minutes: number;
  point_cost: number;
  is_claimed: boolean;
}

interface CustomQuestion {
  id: number;
  category: string;
  question: string;
  options: string[];
  correct_index: number;
  points: number;
}

import useSWR from "swr";

export default function GamificationPage({ params }: { params: Promise<{ id: string }> }) {
  const unwrappedParams = use(params);
  const profileId = unwrappedParams.id;
  
  const [successMsg, setSuccessMsg] = useState("");
  const [actionError, setActionError] = useState("");
  const router = useRouter();

  const fetcher = async (url: string) => {
    try {
      return await fetchAPI(url);
    } catch (err: any) {
      if (err.message.includes("Non autorisé") || err.message.includes("credentials")) {
        router.push("/login");
      }
      throw err;
    }
  };

  const { data: profilesData = [], error: profilesError } = useSWR("/profiles/", fetcher);
  const { data: summary, error: summaryError } = useSWR(`/profiles/${profileId}/gamification`, fetcher);
  const { data: rewards = [], error: rewardsError, mutate: mutateRewards } = useSWR(`/profiles/${profileId}/rewards`, fetcher);
  const { data: questions = [], error: questionsError, mutate: mutateQuestions } = useSWR(`/profiles/${profileId}/custom-questions`, fetcher);

  const profile = profilesData.find((p: Profile) => p.id === parseInt(profileId));
  const loading = !profilesData.length || !summary;
  const error = (profilesError || summaryError || rewardsError || questionsError) ? "Erreur de chargement" : actionError;

  const handleAddQuestion = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setSuccessMsg("");
    setActionError("");
    const formData = new FormData(e.currentTarget);
    
    const options = [
      formData.get("option0") as string,
      formData.get("option1") as string,
      formData.get("option2") as string,
      formData.get("option3") as string,
    ];
    
    const body = {
      category: formData.get("category") as string,
      question: formData.get("question") as string,
      options,
      correct_index: parseInt(formData.get("correct_index") as string),
      points: parseInt(formData.get("points") as string)
    };

    try {
      await fetchAPI(`/profiles/${profileId}/custom-questions`, {
        method: "POST",
        body: JSON.stringify(body),
      });
      mutateQuestions();
      setSuccessMsg("Question ajoutée avec succès !");
      (e.target as HTMLFormElement).reset();
      setTimeout(() => setSuccessMsg(""), 3000);
    } catch (err: any) {
      setActionError(err.message || "Erreur lors de l'ajout");
    }
  };

  const deleteQuestion = async (id: number) => {
    if (!confirm("Supprimer cette question ?")) return;
    
    // Optimistic delete
    mutateQuestions(questions.filter((q: CustomQuestion) => q.id !== id), false);
    
    try {
      await fetchAPI(`/profiles/${profileId}/custom-questions/${id}`, { method: "DELETE" });
      mutateQuestions();
      setSuccessMsg("Question supprimée.");
      setTimeout(() => setSuccessMsg(""), 3000);
    } catch (err: any) {
      setActionError(err.message || "Erreur");
      mutateQuestions(); // Revert
    }
  };

  const handleAddReward = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setSuccessMsg("");
    setActionError("");
    const formData = new FormData(e.currentTarget);
    
    const body = {
      title: formData.get("title") as string,
      description: formData.get("description") as string,
      bonus_minutes: parseInt(formData.get("bonus_minutes") as string),
      point_cost: parseInt(formData.get("point_cost") as string)
    };

    try {
      await fetchAPI(`/profiles/${profileId}/reward`, {
        method: "POST",
        body: JSON.stringify(body),
      });
      mutateRewards();
      setSuccessMsg("Récompense ajoutée avec succès !");
      (e.target as HTMLFormElement).reset();
      setTimeout(() => setSuccessMsg(""), 3000);
    } catch (err: any) {
      setActionError(err.message || "Erreur lors de l'ajout");
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
            &larr; Retour
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-mesh pb-20">
      <nav className="sticky top-0 z-50 glass border-b border-white/20 px-6 py-4">
        <div className="max-w-6xl mx-auto flex items-center gap-4">
          <Link href={`/dashboard/${profileId}`} className="flex items-center gap-2 text-text-muted hover:text-primary transition-colors font-medium">
            <ArrowLeft className="w-5 h-5" />
            <span>Retour au profil</span>
          </Link>
          <div className="h-6 w-px bg-gray-300"></div>
          <h1 className="text-xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-primary to-primary-dark">
            Gamification · {profile.name}
          </h1>
        </div>
      </nav>

      <main className="max-w-4xl mx-auto px-6 py-10 animate-slide-up">
        
        {error && (
          <div className="bg-danger/10 border border-danger/20 text-danger p-4 rounded-xl mb-6 flex items-center gap-3">
            <ShieldAlert className="w-5 h-5 flex-shrink-0" />
            <p className="font-medium">{error}</p>
          </div>
        )}
        {successMsg && (
          <div className="bg-success/10 border border-success/20 text-success p-4 rounded-xl mb-6 flex items-center gap-3">
            <CheckCircle2 className="w-5 h-5 flex-shrink-0" />
            <p className="font-medium">{successMsg}</p>
          </div>
        )}

        {/* Gamification Summary */}
        {summary && (
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-8">
            <div className="glass bg-white/80 p-6 rounded-2xl text-center shadow-sm border border-white/50">
              <Trophy className="w-8 h-8 text-yellow-500 mx-auto mb-2" />
              <div className="text-sm font-bold text-gray-500 uppercase">Points</div>
              <div className="text-2xl font-black text-gray-900">{summary.total_points}</div>
            </div>
            <div className="glass bg-white/80 p-6 rounded-2xl text-center shadow-sm border border-white/50">
              <Star className="w-8 h-8 text-primary mx-auto mb-2" />
              <div className="text-sm font-bold text-gray-500 uppercase">Niveau</div>
              <div className="text-2xl font-black text-gray-900">Lvl {summary.avatar_level}</div>
            </div>
            <div className="glass bg-white/80 p-6 rounded-2xl text-center shadow-sm border border-white/50">
              <Target className="w-8 h-8 text-orange-500 mx-auto mb-2" />
              <div className="text-sm font-bold text-gray-500 uppercase">Série</div>
              <div className="text-2xl font-black text-gray-900">{summary.current_streak} j</div>
            </div>
            <div className="glass bg-white/80 p-6 rounded-2xl text-center shadow-sm border border-white/50">
              <span className="text-3xl block mx-auto mb-2">🔥</span>
              <div className="text-sm font-bold text-gray-500 uppercase">Meilleure</div>
              <div className="text-2xl font-black text-gray-900">{summary.best_streak} j</div>
            </div>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          
          {/* Custom Questions Section */}
          <div className="space-y-6">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center text-primary">
                <span className="text-xl">🧠</span>
              </div>
              <h2 className="text-2xl font-bold text-gray-900">Quiz personnalisés</h2>
            </div>
            <p className="text-sm text-text-muted">Créez des questions auxquelles votre enfant devra répondre pour gagner des points.</p>

            <div className="glass bg-white/80 p-6 rounded-2xl shadow-sm border border-white/50">
              <form onSubmit={handleAddQuestion} className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <input name="category" placeholder="Catégorie (ex: Maths, Maison)" required className="px-4 py-2 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 text-gray-900 text-sm" />
                  <input name="points" type="number" min="1" placeholder="Points à gagner" required className="px-4 py-2 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 text-gray-900 text-sm" />
                </div>
                <input name="question" placeholder="Question (ex: Combien font 7x8 ?)" required className="w-full px-4 py-2 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 text-gray-900 text-sm" />
                
                <div className="space-y-2">
                  <label className="text-xs font-bold text-gray-500 uppercase">Options de réponse (4 requises)</label>
                  {[0,1,2,3].map(i => (
                    <div key={i} className="flex items-center gap-2">
                      <input type="radio" name="correct_index" value={i} required title="Réponse correcte" />
                      <input name={`option${i}`} placeholder={`Option ${i+1}`} required className="flex-1 px-4 py-2 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 text-gray-900 text-sm" />
                    </div>
                  ))}
                </div>
                
                <button type="submit" className="w-full bg-primary hover:bg-primary-dark text-white px-4 py-2 rounded-lg font-medium transition-all shadow-sm flex items-center justify-center gap-2">
                  <Plus className="w-4 h-4" /> Ajouter la question
                </button>
              </form>
            </div>

            <div className="space-y-3 mt-6">
              {questions.length === 0 ? (
                <div className="text-center p-6 text-gray-500 text-sm">Aucune question personnalisée.</div>
              ) : questions.map((q: CustomQuestion) => (
                <div key={q.id} className="glass bg-white/60 p-4 rounded-xl border border-gray-100 flex justify-between items-start group">
                  <div>
                    <span className="text-xs font-bold text-primary bg-primary/10 px-2 py-0.5 rounded-full">{q.category}</span>
                    <h4 className="font-semibold text-gray-900 mt-1">{q.question}</h4>
                    <p className="text-xs text-gray-500 mt-1">Gains : {q.points} pts | Rép : {q.options[q.correct_index]}</p>
                  </div>
                  <button onClick={() => deleteQuestion(q.id)} className="text-gray-400 hover:text-danger opacity-0 group-hover:opacity-100 transition-all">
                    <Trash2 className="w-5 h-5" />
                  </button>
                </div>
              ))}
            </div>
          </div>

          {/* Rewards Section */}
          <div className="space-y-6">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-10 h-10 rounded-xl bg-success/10 flex items-center justify-center text-success">
                <Gift className="w-6 h-6" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900">Boutique de Récompenses</h2>
            </div>
            <p className="text-sm text-text-muted">Proposez du temps d'écran supplémentaire contre des points de confiance.</p>

            <div className="glass bg-white/80 p-6 rounded-2xl shadow-sm border border-white/50">
              <form onSubmit={handleAddReward} className="space-y-4">
                <input name="title" placeholder="Titre (ex: 30 minutes de TikTok)" required className="w-full px-4 py-2 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-success/50 text-gray-900 text-sm" />
                <input name="description" placeholder="Description (optionnelle)" className="w-full px-4 py-2 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-success/50 text-gray-900 text-sm" />
                
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="text-xs font-bold text-gray-500">Temps bonus (min)</label>
                    <input name="bonus_minutes" type="number" min="1" required className="w-full mt-1 px-4 py-2 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-success/50 text-gray-900 text-sm" />
                  </div>
                  <div>
                    <label className="text-xs font-bold text-gray-500">Coût en points</label>
                    <input name="point_cost" type="number" min="1" required className="w-full mt-1 px-4 py-2 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-success/50 text-gray-900 text-sm" />
                  </div>
                </div>
                
                <button type="submit" className="w-full bg-success hover:bg-success/90 text-white px-4 py-2 rounded-lg font-medium transition-all shadow-sm flex items-center justify-center gap-2">
                  <Plus className="w-4 h-4" /> Ajouter la récompense
                </button>
              </form>
            </div>

            <div className="space-y-3 mt-6">
              {rewards.length === 0 ? (
                <div className="text-center p-6 text-gray-500 text-sm">Aucune récompense disponible.</div>
              ) : rewards.map((r: Reward) => (
                <div key={r.id} className={`glass p-4 rounded-xl border flex justify-between items-center ${r.is_claimed ? 'bg-gray-50 border-gray-200 opacity-60' : 'bg-white border-success/20'}`}>
                  <div>
                    <h4 className={`font-semibold ${r.is_claimed ? 'text-gray-500 line-through' : 'text-gray-900'}`}>{r.title}</h4>
                    <p className="text-xs text-gray-500 mt-0.5">+{r.bonus_minutes} min</p>
                  </div>
                  <div className={`px-3 py-1 rounded-full text-xs font-bold ${r.is_claimed ? 'bg-gray-200 text-gray-600' : 'bg-success/10 text-success'}`}>
                    {r.is_claimed ? 'Réclamée' : `${r.point_cost} pts`}
                  </div>
                </div>
              ))}
            </div>
          </div>

        </div>
      </main>
    </div>
  );
}
