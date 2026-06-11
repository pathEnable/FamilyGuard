"use client";

import { useState, useEffect } from "react";
import { X, User, Calendar } from "lucide-react";
import { fetchAPI } from "@/lib/api";

type ProfileModalProps = {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  profile?: { id: string; name: string; age: number } | null;
};

export default function ProfileModal({ isOpen, onClose, onSuccess, profile }: ProfileModalProps) {
  const [name, setName] = useState("");
  const [age, setAge] = useState<number | "">("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (profile) {
      setName(profile.name);
      setAge(profile.age);
    } else {
      setName("");
      setAge("");
    }
  }, [profile, isOpen]);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      if (profile) {
        // Edit
        await fetchAPI(`/profiles/${profile.id}`, {
          method: "PUT",
          body: JSON.stringify({ name, age: Number(age) }),
        });
      } else {
        // Create
        await fetchAPI("/profiles/", {
          method: "POST",
          body: JSON.stringify({ name, age: Number(age) }),
        });
      }
      onSuccess();
      onClose();
    } catch (err: any) {
      setError(err.message || "Une erreur est survenue");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/40 backdrop-blur-sm animate-fade-in">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 relative animate-slide-up">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 w-8 h-8 flex items-center justify-center rounded-full hover:bg-gray-100 text-gray-500 transition-colors"
        >
          <X className="w-5 h-5" />
        </button>

        <h2 className="text-2xl font-bold text-gray-900 mb-6">
          {profile ? "Modifier le profil" : "Ajouter un profil"}
        </h2>

        {error && (
          <div className="mb-4 p-3 bg-red-50 text-red-600 rounded-lg text-sm border border-red-100">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Prénom</label>
            <div className="relative">
              <User className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type="text"
                required
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary focus:border-primary outline-none transition-all text-gray-900 bg-gray-50 focus:bg-white"
                placeholder="Ex: Léo"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Âge</label>
            <div className="relative">
              <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type="number"
                required
                min="1"
                max="18"
                value={age}
                onChange={(e) => setAge(e.target.value ? Number(e.target.value) : "")}
                className="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-xl focus:ring-2 focus:ring-primary focus:border-primary outline-none transition-all text-gray-900 bg-gray-50 focus:bg-white"
                placeholder="Ex: 12"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-gradient-to-r from-primary to-primary-dark text-white font-medium py-3 rounded-xl hover:from-primary-dark hover:to-[#173587] transition-all shadow-md shadow-primary/20 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? "Enregistrement..." : profile ? "Enregistrer les modifications" : "Créer le profil"}
          </button>
        </form>
      </div>
    </div>
  );
}
