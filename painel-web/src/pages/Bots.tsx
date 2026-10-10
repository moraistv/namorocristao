import { useEffect, useRef, useState } from "react";
import {
  IconBrain,
  IconCheck,
  IconAlertTriangle,
  IconClock,
  IconDatabase,
  IconEdit,
  IconHeart,
  IconMoodSmile,
  IconPhoto,
  IconPlus,
  IconRefresh,
  IconRobot,
  IconSend,
  IconTrash,
} from "@tabler/icons-react";
import EmojiPicker from "emoji-picker-react";
import { API_BASE, ApiError, del, get, post, put } from "../api";
import { Dialog, DialogConfig, Toast, ToastMsg } from "../components/ui";
import { useModalAccessibility } from "../components/useModalAccessibility";

const ORIGIN = API_BASE.replace(/\/api$/, "");
const PERSONALITY: Record<string, string> = {
  ALL: "Equilibrada",
  SHY: "Tímida",
  FUNNY: "Engraçada",
  EXTROVERT: "Extrovertida",
};
const EMOJIS = ["😊", "💛", "😍", "🙏", "✨", "💕", "😘", "🌹", "💖", "🥰", "😇", "💝"];
const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;
const UPLOAD_TIMEOUT_MS = 60_000;
const MODEL_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:/-]{0,99}$/;
const BROADCAST_ATTEMPT_STORAGE_KEY = "namoro-cristao:bot-broadcast-attempt:v1";
type AiProvider = "deepseek" | "openai";
type BroadcastStatus = "PENDING" | "PROCESSING" | "COMPLETED" | "FAILED";
const ALLOWED_IMAGE_TYPES: Record<string, string> = {
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  png: "image/png",
  webp: "image/webp",
};

interface Bot {
  userId: string;
  fullName: string;
  gender: string | null;
  age: number | null;
  about: string | null;
  city: string | null;
  interests: string[];
  photos: string[];
  profilePicture: string | null;
  personality: string;
  aiEnabled: boolean;
  botSystemPrompt: string | null;
  botAiModel: string | null;
  botAiModelProvider: AiProvider | null;
  botTemperature: number;
  botMemoryEnabled: boolean;
  matchCount: number;
  memoryCount: number;
}

interface BotsResponse {
  bots?: Bot[];
  globalAiProvider?: AiProvider | null;
}

interface UploadResponse {
  url: string;
}

interface DeleteMemoriesResponse {
  deletedCount?: number;
}

interface BroadcastHistory {
  id: string;
  text: string | null;
  audience: string;
  status: BroadcastStatus;
  sent: number;
  targeted: number;
  skipped?: number;
  failedCount?: number;
  sentAt: string | null;
  createdAt?: string;
  processing: boolean;
  failed: boolean;
  lastError?: string | null;
  idempotencyKey: string;
}

interface BroadcastHistoryResponse {
  history?: BroadcastHistory[];
}

interface BroadcastRequest {
  audience: string;
  idempotencyKey: string;
  text?: string;
  imageUrl?: string;
}

interface BroadcastResponse {
  broadcastId?: string;
  sent?: number;
  targeted?: number;
  skipped?: number;
  failedCount?: number;
  status?: BroadcastStatus;
  duplicate?: boolean;
  processing?: boolean;
  failed?: boolean;
  lastError?: string | null;
  idempotencyKey?: string;
}

interface BroadcastAttempt {
  botId: string;
  signature: string;
  idempotencyKey: string;
  request: BroadcastRequest;
  response?: BroadcastResponse;
}

interface BroadcastResult {
  response: BroadcastResponse;
  idempotencyKey: string;
}

interface Form {
  userId?: string;
  fullName: string;
  gender: string;
  age: number;
  about: string;
  city: string;
  interests: string;
  photos: string[];
  personality: string;
  aiEnabled: boolean;
  botSystemPrompt: string;
  botAiModel: string;
  botAiModelProvider: AiProvider | "";
  botTemperature: number;
  botMemoryEnabled: boolean;
}

const emptyForm: Form = {
  fullName: "",
  gender: "FEMALE",
  age: 24,
  about: "",
  city: "",
  interests: "",
  photos: [],
  personality: "ALL",
  aiEnabled: true,
  botSystemPrompt: "",
  botAiModel: "",
  botAiModelProvider: "",
  botTemperature: 0.75,
  botMemoryEnabled: true,
};

function errorMessage(error: unknown, fallback = "Não foi possível concluir a operação") {
  return error instanceof Error && error.message ? error.message : fallback;
}

function isHttpUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "http:" || url.protocol === "https:";
  } catch {
    return false;
  }
}

function isAiProvider(value: unknown): value is AiProvider {
  return value === "deepseek" || value === "openai";
}

function isAiModelCompatible(provider: AiProvider, model: string): boolean {
  const normalized = model.trim().toLowerCase();
  if (provider === "deepseek") {
    return normalized === "deepseek-chat" || normalized === "deepseek-reasoner";
  }
  const baseModel = normalized.startsWith("ft:")
    ? normalized.slice(3)
    : normalized;
  return /^(?:gpt-|chatgpt-|o(?:1|3|4)(?:-|$))/.test(baseModel);
}

function safeCount(value: number | undefined): number {
  return typeof value === "number" && Number.isFinite(value)
    ? Math.max(0, Math.trunc(value))
    : 0;
}

function formatHistoryDate(value: string | null): string {
  if (!value) return "Processando";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "Data indisponível" : date.toLocaleString("pt-BR");
}

function createSecureIdempotencyKey(): string {
  if (typeof crypto === "undefined" || typeof crypto.getRandomValues !== "function") {
    throw new Error("Este navegador não oferece geração segura para iniciar o disparo.");
  }
  if (typeof crypto.randomUUID === "function") return crypto.randomUUID();

  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function clearStoredBroadcastAttempt(): boolean {
  if (typeof window === "undefined") return true;
  try {
    window.localStorage.removeItem(BROADCAST_ATTEMPT_STORAGE_KEY);
    return true;
  } catch {
    return false;
  }
}

function loadStoredBroadcastAttempt(): BroadcastAttempt | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(BROADCAST_ATTEMPT_STORAGE_KEY);
    if (!raw) return null;
    const value = JSON.parse(raw) as Partial<BroadcastAttempt>;
    const request = value.request as Partial<BroadcastRequest> | undefined;
    if (
      typeof value.botId !== "string" ||
      typeof value.signature !== "string" ||
      typeof value.idempotencyKey !== "string" ||
      !request ||
      request.idempotencyKey !== value.idempotencyKey ||
      typeof request.audience !== "string"
    ) {
      clearStoredBroadcastAttempt();
      return null;
    }
    return value as BroadcastAttempt;
  } catch {
    return null;
  }
}

function storeBroadcastAttempt(attempt: BroadcastAttempt | null): boolean {
  if (typeof window === "undefined") return true;
  if (!attempt) return clearStoredBroadcastAttempt();
  try {
    window.localStorage.setItem(BROADCAST_ATTEMPT_STORAGE_KEY, JSON.stringify(attempt));
    return true;
  } catch {
    return false;
  }
}

function isCompletedBroadcast(response: BroadcastResponse): boolean {
  return response.status === "COMPLETED";
}

function isUncertainBroadcastFailure(error: unknown): boolean {
  return error instanceof ApiError && (
    error.code === "TIMEOUT" ||
    error.code === "NETWORK" ||
    error.code === "ABORTED" ||
    error.status >= 500
  );
}

function broadcastResultText(result: BroadcastResult): string {
  const { response } = result;
  const sent = safeCount(response.sent);
  const targeted = safeCount(response.targeted);
  const progress = targeted > 0 ? `${sent}/${targeted}` : String(sent);
  if (response.status === "FAILED" || response.failed) {
    const failures = safeCount(response.failedCount);
    return `Tentativa com falhas: ${progress} mensagem(ns) persistida(s)${failures > 0 ? `; ${failures} falha(s) retomável(is)` : ""}. Use Retomar tentativa com a mesma chave.`;
  }
  const processing =
    response.status === "PENDING" || response.status === "PROCESSING";
  if (processing && response.duplicate) {
    return `Tentativa anterior em processamento (${progress}). A mesma chave foi preservada; nenhuma entrega push foi presumida.`;
  }
  if (processing) {
    return `Tentativa em processamento (${progress}). A mesma chave foi preservada; nenhuma entrega push foi presumida.`;
  }
  if (response.duplicate) {
    return `Tentativa concluída reconhecida: ${progress} mensagem(ns) persistida(s). Isso não confirma entrega push.`;
  }
  return `${progress} mensagem(ns) persistida(s) no servidor. Isso não confirma entrega push.`;
}

async function fileToBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result).split(",")[1] || "");
    reader.onerror = () => reject(reader.error ?? new Error("Não foi possível ler a imagem."));
    reader.readAsDataURL(file);
  });
}

export default function Bots() {
  const [bots, setBots] = useState<Bot[]>([]);
  const [globalAiProvider, setGlobalAiProvider] = useState<AiProvider | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState<Form | null>(null);
  const [formUploading, setFormUploading] = useState(false);
  const [blast, setBlast] = useState<Bot | null>(null);
  const [blastText, setBlastText] = useState("");
  const [blastImage, setBlastImage] = useState("");
  const [blastImageUrl, setBlastImageUrl] = useState("");
  const [blastAudience, setBlastAudience] = useState("all");
  const [blastUploading, setBlastUploading] = useState(false);
  const [blastSending, setBlastSending] = useState(false);
  const [blastResult, setBlastResult] = useState<BroadcastResult | null>(null);
  const [broadcastAttempt, setBroadcastAttempt] = useState<BroadcastAttempt | null>(loadStoredBroadcastAttempt);
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [history, setHistory] = useState<BroadcastHistory[]>([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyError, setHistoryError] = useState("");
  const [showHistory, setShowHistory] = useState(false);
  const [dialog, setDialog] = useState<DialogConfig | null>(null);
  const [toast, setToast] = useState<ToastMsg | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const blastImageRef = useRef<HTMLInputElement>(null);
  const historyRequestRef = useRef(0);
  const activeBroadcastBotIdRef = useRef<string | null>(null);

  const formModalRef = useModalAccessibility({
    open: Boolean(form),
    onClose: closeForm,
    canClose: !saving && !formUploading,
  });
  const broadcastModalRef = useModalAccessibility({
    open: Boolean(blast),
    onClose: closeBroadcast,
    canClose: !blastSending && !blastUploading,
  });

  function updateBroadcastAttempt(attempt: BroadcastAttempt | null): boolean {
    const stored = storeBroadcastAttempt(attempt);
    if (stored) setBroadcastAttempt(attempt);
    return stored;
  }

  async function load() {
    setLoading(true);
    setLoadError("");
    try {
      const response = await get<BotsResponse>("/admin/bots");
      setBots(Array.isArray(response.bots) ? response.bots : []);
      setGlobalAiProvider(
        isAiProvider(response.globalAiProvider)
          ? response.globalAiProvider
          : null
      );
    } catch (error: unknown) {
      setLoadError(errorMessage(error, "Não foi possível carregar os perfis virtuais."));
    } finally {
      setLoading(false);
    }
  }

  async function loadHistory(botId: string) {
    const request = ++historyRequestRef.current;
    setHistoryLoading(true);
    setHistoryError("");
    try {
      const response = await get<BroadcastHistoryResponse>(`/admin/bots/${botId}/broadcasts`);
      if (request !== historyRequestRef.current || activeBroadcastBotIdRef.current !== botId) return;
      setHistory(Array.isArray(response.history) ? response.history : []);
    } catch (error: unknown) {
      if (request !== historyRequestRef.current || activeBroadcastBotIdRef.current !== botId) return;
      setHistoryError(errorMessage(error, "Não foi possível carregar o histórico."));
    } finally {
      if (request === historyRequestRef.current && activeBroadcastBotIdRef.current === botId) {
        setHistoryLoading(false);
      }
    }
  }

  useEffect(() => {
    void load();
    return () => {
      historyRequestRef.current += 1;
      activeBroadcastBotIdRef.current = null;
    };
  }, []);

  function closeForm() {
    if (saving || formUploading) return;
    setForm(null);
  }

  function closeBroadcast() {
    if (blastSending || blastUploading) return;
    activeBroadcastBotIdRef.current = null;
    historyRequestRef.current += 1;
    setBlast(null);
    setHistory([]);
    setHistoryError("");
    setHistoryLoading(false);
    setShowEmojiPicker(false);
  }

  function openNew() {
    if (saving || formUploading) return;
    setForm({ ...emptyForm, photos: [] });
  }

  function openEdit(bot: Bot) {
    if (saving || formUploading) return;
    setForm({
      userId: bot.userId,
      fullName: bot.fullName,
      gender: bot.gender || "FEMALE",
      age: bot.age ?? 24,
      about: bot.about || "",
      city: bot.city || "",
      interests: bot.interests.join(", "),
      photos: [...bot.photos],
      personality: bot.personality,
      aiEnabled: bot.aiEnabled,
      botSystemPrompt: bot.botSystemPrompt || "",
      botAiModel: bot.botAiModel || "",
      botAiModelProvider:
        bot.botAiModel && isAiProvider(bot.botAiModelProvider)
          ? bot.botAiModelProvider
          : "",
      botTemperature: bot.botTemperature ?? 0.75,
      botMemoryEnabled: bot.botMemoryEnabled,
    });
  }

  function validateImage(file: File): string | null {
    const extension = (file.name.split(".").pop() || "").toLowerCase();
    const expectedMime = ALLOWED_IMAGE_TYPES[extension];
    if (!expectedMime || file.type !== expectedMime) {
      setToast({ type: "error", text: "Use somente imagens JPG, JPEG, PNG ou WEBP." });
      return null;
    }
    if (file.size > MAX_UPLOAD_BYTES) {
      setToast({ type: "error", text: "A imagem deve ter no máximo 5 MB." });
      return null;
    }
    return extension;
  }

  async function uploadImage(file: File, extension: string): Promise<string> {
    const image = await fileToBase64(file);
    if (!image) throw new Error("A imagem selecionada está vazia ou não pôde ser lida.");

    const response = await post<UploadResponse>(
      "/admin/gifts/upload",
      { image, ext: extension },
      { timeoutMs: UPLOAD_TIMEOUT_MS }
    );
    if (!response || typeof response.url !== "string" || !response.url.trim()) {
      throw new ApiError("O servidor retornou uma URL de imagem inválida.", 200, "INVALID_RESPONSE");
    }

    const rawUrl = response.url.trim();
    const resolvedUrl = /^https?:\/\//i.test(rawUrl) ? rawUrl : `${ORIGIN}${rawUrl}`;
    if (!isHttpUrl(resolvedUrl)) {
      throw new ApiError("O servidor retornou uma URL de imagem inválida.", 200, "INVALID_RESPONSE");
    }
    return resolvedUrl;
  }

  async function onPickFile(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    const extension = file ? validateImage(file) : null;
    if (!file || !extension || !form || formUploading || saving) return;
    if (form.photos.length >= 6) {
      setToast({ type: "error", text: "O perfil pode ter no máximo 6 fotos." });
      return;
    }

    setFormUploading(true);
    try {
      const url = await uploadImage(file, extension);
      setForm((current) => current && current.photos.length < 6
        ? { ...current, photos: [...current.photos, url] }
        : current);
    } catch (error: unknown) {
      setToast({ type: "error", text: errorMessage(error, "Falha no upload") });
    } finally {
      setFormUploading(false);
      if (fileRef.current) fileRef.current.value = "";
    }
  }

  async function save() {
    if (!form || saving || formUploading) return;

    const fullName = form.fullName.trim();
    const interests = form.interests
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);
    const model = form.botAiModel.trim();
    const prompt = form.botSystemPrompt.trim();

    if (fullName.length < 2 || fullName.length > 80) {
      setToast({ type: "error", text: "Informe um nome entre 2 e 80 caracteres." });
      return;
    }
    if (!Number.isInteger(form.age) || form.age < 18 || form.age > 99) {
      setToast({ type: "error", text: "A idade deve ser um número inteiro entre 18 e 99." });
      return;
    }
    if (!Number.isFinite(form.botTemperature) || form.botTemperature < 0 || form.botTemperature > 2) {
      setToast({ type: "error", text: "A criatividade deve estar entre 0 e 2." });
      return;
    }
    if (model && !MODEL_PATTERN.test(model)) {
      setToast({ type: "error", text: "O modelo deve ter 1 a 100 caracteres e usar apenas letras, números, ponto, hífen, sublinhado, dois-pontos ou barra." });
      return;
    }
    if (model && !form.botAiModelProvider) {
      setToast({ type: "error", text: "Selecione o provider vinculado ao modelo individual." });
      return;
    }
    if (
      model &&
      form.botAiModelProvider &&
      !isAiModelCompatible(form.botAiModelProvider, model)
    ) {
      setToast({ type: "error", text: "O modelo informado não pertence ao provider selecionado." });
      return;
    }
    if (!model && form.botAiModelProvider) {
      setToast({ type: "error", text: "Informe um modelo para usar o provider individual." });
      return;
    }
    if (interests.length > 10) {
      setToast({ type: "error", text: "Informe no máximo 10 interesses." });
      return;
    }
    if (interests.some((interest) => interest.length > 40)) {
      setToast({ type: "error", text: "Cada interesse deve ter no máximo 40 caracteres." });
      return;
    }
    if (form.photos.length < 1 || form.photos.length > 6) {
      setToast({ type: "error", text: "Adicione entre 1 e 6 fotos." });
      return;
    }
    if (form.photos.some((photo) => !isHttpUrl(photo))) {
      setToast({ type: "error", text: "Todas as fotos precisam ter URLs HTTP ou HTTPS válidas." });
      return;
    }
    if (prompt.length > 4000) {
      setToast({ type: "error", text: "A instrução exclusiva deve ter no máximo 4000 caracteres." });
      return;
    }

    const body = {
      fullName,
      gender: form.gender,
      age: form.age,
      about: form.about.trim() || null,
      city: form.city.trim() || null,
      interests,
      photos: form.photos,
      personality: form.personality,
      aiEnabled: form.aiEnabled,
      botSystemPrompt: prompt || null,
      botAiModel: model || null,
      botAiModelProvider: model ? form.botAiModelProvider : null,
      botTemperature: form.botTemperature,
      botMemoryEnabled: form.botMemoryEnabled,
    };

    setSaving(true);
    try {
      if (form.userId) await put<void>(`/admin/bots/${form.userId}`, body);
      else await post<void>("/admin/bots", body);
      setForm(null);
      await load();
      setToast({ type: "success", text: "Perfil virtual salvo com sucesso." });
    } catch (error: unknown) {
      setToast({ type: "error", text: errorMessage(error) });
    } finally {
      setSaving(false);
    }
  }

  function resetMemories(bot: Bot) {
    setDialog({
      title: "Limpar memórias da IA",
      message: `Apagar ${bot.memoryCount} memória(s) de ${bot.fullName}? As mensagens continuam salvas, mas o resumo de longo prazo será recomeçado.`,
      icon: IconDatabase,
      danger: true,
      confirmText: "Limpar memórias",
      onConfirm: async () => {
        try {
          const response = await del<DeleteMemoriesResponse>(`/admin/bots/${bot.userId}/memories`);
          await load();
          setToast({ type: "success", text: `${safeCount(response.deletedCount)} memória(s) removida(s).` });
        } catch (error: unknown) {
          setToast({ type: "error", text: errorMessage(error) });
          throw error;
        }
      },
    });
  }

  function remove(bot: Bot) {
    if (broadcastAttempt?.botId === bot.userId) {
      setToast({
        type: "error",
        text: "Conclua a tentativa de broadcast ou confirme Novo disparo antes de excluir este perfil.",
      });
      return;
    }
    setDialog({
      title: "Excluir perfil virtual",
      message: `Remover ${bot.fullName}? Essa ação apaga os matches, as conversas e as memórias desse perfil.`,
      icon: IconTrash,
      danger: true,
      confirmText: "Excluir",
      onConfirm: async () => {
        try {
          await del<void>(`/admin/bots/${bot.userId}`);
          await load();
          setToast({ type: "success", text: "Perfil virtual excluído." });
        } catch (error: unknown) {
          setToast({ type: "error", text: errorMessage(error) });
          throw error;
        }
      },
    });
  }

  function invalidateBroadcastAttempt() {
    if (!broadcastAttempt) setBlastResult(null);
  }

  function openBroadcast(bot: Bot) {
    if (broadcastAttempt && broadcastAttempt.botId !== bot.userId) {
      setToast({
        type: "error",
        text: "Há uma tentativa não concluída em outro perfil. Retome-a ou confirme Novo disparo antes de iniciar outra.",
      });
      return;
    }

    const activeAttempt =
      broadcastAttempt?.botId === bot.userId ? broadcastAttempt : null;
    activeBroadcastBotIdRef.current = bot.userId;
    historyRequestRef.current += 1;
    setBlast(bot);
    setBlastText(activeAttempt?.request.text ?? "");
    setBlastImage("");
    setBlastImageUrl(activeAttempt?.request.imageUrl ?? "");
    setBlastAudience(activeAttempt?.request.audience ?? "all");
    setBlastResult(
      activeAttempt?.response
        ? {
            response: activeAttempt.response,
            idempotencyKey: activeAttempt.idempotencyKey,
          }
        : null
    );
    setHistory([]);
    setHistoryError("");
    setHistoryLoading(false);
    setShowHistory(false);
    setShowEmojiPicker(false);
    void loadHistory(bot.userId);
  }

  function requestNewBroadcast() {
    if (!broadcastAttempt) return;
    setDialog({
      title: "Iniciar novo disparo",
      message: "A tentativa atual ainda não foi concluída. Uma nova chave pode alcançar novamente destinatários da tentativa anterior. Confirma abandonar a retomada e liberar um novo payload?",
      icon: IconAlertTriangle,
      danger: true,
      confirmText: "Novo disparo",
      onConfirm: async () => {
        updateBroadcastAttempt(null);
        setBlastResult(null);
        setBlastText("");
        setBlastImage("");
        setBlastImageUrl("");
        setBlastAudience("all");
      },
    });
  }

  async function onPickBlastImage(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    const extension = file ? validateImage(file) : null;
    if (!file || !extension || !blast || blastUploading || blastSending) return;

    setBlastUploading(true);
    try {
      const imageUrl = await uploadImage(file, extension);
      setBlastImage(imageUrl);
      setBlastImageUrl("");
      invalidateBroadcastAttempt();
    } catch (error: unknown) {
      setToast({ type: "error", text: errorMessage(error, "Falha no upload") });
    } finally {
      setBlastUploading(false);
      if (blastImageRef.current) blastImageRef.current.value = "";
    }
  }

  async function sendBlast() {
    if (!blast || blastSending || blastUploading) return;
    const botId = blast.userId;
    if (broadcastAttempt && broadcastAttempt.botId !== botId) {
      setToast({ type: "error", text: "A tentativa preservada pertence a outro perfil." });
      return;
    }

    const activeRequest = broadcastAttempt?.request;
    const text = (activeRequest?.text ?? blastText).trim();
    const imageUrl = activeRequest?.imageUrl ?? (blastImageUrl.trim() || blastImage);
    const audience = activeRequest?.audience ?? blastAudience;
    if (!text && !imageUrl) {
      setToast({ type: "error", text: "Escreva a mensagem ou adicione uma imagem." });
      return;
    }
    if (text.length > 500) {
      setToast({ type: "error", text: "A mensagem deve ter no máximo 500 caracteres." });
      return;
    }
    if (imageUrl && !isHttpUrl(imageUrl)) {
      setToast({ type: "error", text: "Informe uma URL HTTP ou HTTPS válida para a imagem." });
      return;
    }

    let attempt = broadcastAttempt;
    if (!attempt) {
      let idempotencyKey: string;
      try {
        idempotencyKey = createSecureIdempotencyKey();
      } catch (error: unknown) {
        setToast({ type: "error", text: errorMessage(error) });
        return;
      }
      const request: BroadcastRequest = { audience, idempotencyKey };
      if (text) request.text = text;
      if (imageUrl) request.imageUrl = imageUrl;
      const signature = JSON.stringify({ botId, audience, text, imageUrl });
      attempt = { botId, signature, idempotencyKey, request };
      if (!updateBroadcastAttempt(attempt)) {
        setBroadcastAttempt(null);
        setToast({
          type: "error",
          text: "Não foi possível preservar a chave neste navegador. O disparo não foi iniciado; habilite o armazenamento local e tente novamente.",
        });
        return;
      }
    }

    setBlastSending(true);
    setBlastResult(null);
    try {
      const response = await post<BroadcastResponse>(
        `/admin/bots/${botId}/broadcast`,
        attempt.request,
        { timeoutMs: null }
      );
      const result = {
        response,
        idempotencyKey: response.idempotencyKey || attempt.idempotencyKey,
      };
      setBlastResult(result);
      if (isCompletedBroadcast(response)) {
        updateBroadcastAttempt(null);
      } else {
        updateBroadcastAttempt({ ...attempt, response });
      }
      await loadHistory(botId);
      setToast({
        type: response.status === "FAILED" ? "error" : "success",
        text: broadcastResultText(result),
      });
    } catch (error: unknown) {
      const prefix = errorMessage(error);
      setToast({
        type: "error",
        text: isUncertainBroadcastFailure(error)
          ? `${prefix} O resultado é incerto; consultar/retomar reutilizará a mesma chave com segurança.`
          : prefix,
      });
    } finally {
      setBlastSending(false);
    }
  }

  const activeBroadcastAttempt =
    blast && broadcastAttempt?.botId === blast.userId
      ? broadcastAttempt
      : null;
  const broadcastDraftLocked = Boolean(activeBroadcastAttempt);
  const preservedBroadcastBot = broadcastAttempt
    ? bots.find((bot) => bot.userId === broadcastAttempt.botId) ?? null
    : null;

  return (
    <>
      <div className="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-3">
        <div>
          <div className="page-pretitle">Automação inteligente</div>
          <h2 className="page-title">Perfis virtuais</h2>
        </div>
        <button type="button" className="btn btn-primary" onClick={openNew}>
          <IconPlus size={16} className="me-1" aria-hidden="true" /> Novo perfil
        </button>
      </div>

      <div className="alert alert-info d-flex align-items-start gap-2" role="note">
        <IconBrain size={20} className="mt-1 flex-shrink-0" aria-hidden="true" />
        <div>
          <strong>IA personalizada com memória de longo prazo.</strong>
          <div className="small">Cada perfil possui voz, modelo e memória próprios e deve ser apresentado ao usuário como perfil virtual de IA.</div>
        </div>
      </div>

      {broadcastAttempt && (
        <div className="alert alert-warning d-flex flex-wrap align-items-center gap-2" role="status">
          <IconClock size={18} aria-hidden="true" />
          <span className="flex-fill">Tentativa preservada <strong>{broadcastAttempt.idempotencyKey.slice(0, 8)}…</strong>{preservedBroadcastBot ? ` em ${preservedBroadcastBot.fullName}` : " para um perfil não disponível"}.</span>
          {preservedBroadcastBot && <button type="button" className="btn btn-sm" onClick={() => openBroadcast(preservedBroadcastBot)}>Consultar / retomar</button>}
          <button type="button" className="btn btn-sm btn-outline-danger" onClick={requestNewBroadcast}>Novo disparo</button>
        </div>
      )}

      {loadError && (
        <div className="alert alert-danger retry-state" role="alert">
          <span>{loadError}</span>
          <button type="button" className="btn btn-sm" onClick={() => void load()}>
            <IconRefresh size={16} className="me-1" aria-hidden="true" /> Tentar novamente
          </button>
        </div>
      )}

      <div className="row row-cards" aria-busy={loading}>
        {bots.map((bot) => (
          <div className="col-md-6 col-xl-4" key={bot.userId}>
            <div className="card h-100 bot-card">
              <div className="card-body d-flex">
                <span className="avatar avatar-xl me-3" style={{ backgroundImage: bot.profilePicture ? `url(${bot.profilePicture})` : undefined }}>
                  {!bot.profilePicture && <IconRobot size={26} aria-hidden="true" />}
                </span>
                <div className="flex-fill" style={{ minWidth: 0 }}>
                  <div className="d-flex align-items-center flex-wrap gap-2">
                    <strong className="text-truncate">{bot.fullName}</strong>
                    {bot.age && <span className="text-secondary">{bot.age}</span>}
                    <span className={`badge ${bot.aiEnabled ? "bg-purple-lt" : "bg-secondary-lt"}`}>
                      {bot.aiEnabled ? "IA ativa" : "IA pausada"}
                    </span>
                  </div>
                  <div className="text-secondary text-truncate mt-1 small">{bot.about || "Bio não informada"}</div>
                  <div className="d-flex flex-wrap gap-2 align-items-center mt-2 small">
                    <span className="badge bg-azure-lt">{PERSONALITY[bot.personality] || bot.personality}</span>
                    <span className="text-secondary"><IconHeart size={14} className="me-1" aria-hidden="true" />{bot.matchCount} matches</span>
                    <span className={bot.botMemoryEnabled ? "text-success" : "text-secondary"}>
                      <IconDatabase size={14} className="me-1" aria-hidden="true" />{bot.memoryCount} memórias
                    </span>
                  </div>
                  {bot.botAiModel && (
                    <div className="text-secondary mt-2" style={{ fontSize: 11 }}>
                      Modelo: {bot.botAiModelProvider === "openai" ? "OpenAI" : bot.botAiModelProvider === "deepseek" ? "DeepSeek" : "provider não vinculado"} / {bot.botAiModel}
                      {globalAiProvider && bot.botAiModelProvider !== globalAiProvider && (
                        <span className="badge bg-yellow-lt ms-2">ignorado no provider global atual</span>
                      )}
                    </div>
                  )}
                </div>
              </div>
              <div className="card-footer d-flex flex-wrap gap-1 justify-content-end">
                {bot.memoryCount > 0 && (
                  <button type="button" className="btn btn-sm btn-icon btn-ghost-warning" onClick={() => resetMemories(bot)} title="Limpar memórias" aria-label={`Limpar memórias de ${bot.fullName}`}>
                    <IconDatabase size={15} aria-hidden="true" />
                  </button>
                )}
                <button type="button" className="btn btn-sm btn-ghost-primary" onClick={() => openBroadcast(bot)}>
                  <IconSend size={15} className="me-1" aria-hidden="true" /> Disparar
                </button>
                <button type="button" className="btn btn-sm" onClick={() => openEdit(bot)}>
                  <IconEdit size={15} className="me-1" aria-hidden="true" /> Editar
                </button>
                <button type="button" className="btn btn-sm btn-icon btn-ghost-danger" onClick={() => remove(bot)} aria-label={`Excluir ${bot.fullName}`}>
                  <IconTrash size={15} aria-hidden="true" />
                </button>
              </div>
            </div>
          </div>
        ))}
        {!loading && !loadError && bots.length === 0 && (
          <div className="col-12">
            <div className="card"><div className="card-body text-center text-secondary py-5">
              <IconRobot size={40} className="mb-2 opacity-50" aria-hidden="true" />
              <div className="fw-medium">Nenhum perfil virtual criado</div>
              <div className="small">Crie o primeiro e configure sua personalidade e memória.</div>
            </div></div>
          </div>
        )}
        {loading && (
          <div className="col-12 text-center text-secondary py-5" role="status" aria-live="polite">
            <span className="spinner-border spinner-border-sm me-2" aria-hidden="true" />
            Carregando perfis...
          </div>
        )}
      </div>

      {form && (
        <>
          <div ref={formModalRef} className="modal modal-blur fade show d-block" tabIndex={-1} role="dialog" aria-modal="true" aria-labelledby="bot-form-title">
            <div className="modal-dialog modal-xl modal-dialog-centered modal-dialog-scrollable" role="document">
              <div className="modal-content">
                <div className="modal-header">
                  <div>
                    <div className="text-secondary small">Perfil virtual identificado como IA</div>
                    <h5 className="modal-title" id="bot-form-title">{form.userId ? "Editar perfil" : "Novo perfil"}</h5>
                  </div>
                  <button type="button" className="btn-close" aria-label="Fechar" disabled={saving || formUploading} onClick={closeForm} />
                </div>
                <div className="modal-body">
                  <fieldset disabled={saving || formUploading} className="border-0 m-0 p-0">
                    <div className="row g-3">
                      <div className="col-md-6"><label className="form-label" htmlFor="bot-name">Nome</label><input id="bot-name" className="form-control" data-modal-initial value={form.fullName} maxLength={80} onChange={(event) => setForm({ ...form, fullName: event.target.value })} /></div>
                      <div className="col-md-3"><label className="form-label" htmlFor="bot-age">Idade</label><input id="bot-age" type="number" min={18} max={99} step={1} className="form-control" value={form.age} onChange={(event) => setForm({ ...form, age: Number(event.target.value) })} /></div>
                      <div className="col-md-3"><label className="form-label" htmlFor="bot-gender">Gênero</label><select id="bot-gender" className="form-select" value={form.gender} onChange={(event) => setForm({ ...form, gender: event.target.value })}><option value="FEMALE">Feminino</option><option value="MALE">Masculino</option><option value="OTHER">Outro</option></select></div>
                      <div className="col-md-8"><label className="form-label" htmlFor="bot-city">Cidade</label><input id="bot-city" className="form-control" value={form.city} maxLength={80} onChange={(event) => setForm({ ...form, city: event.target.value })} /></div>
                      <div className="col-md-4"><label className="form-label" htmlFor="bot-personality">Personalidade</label><select id="bot-personality" className="form-select" value={form.personality} onChange={(event) => setForm({ ...form, personality: event.target.value })}>{Object.entries(PERSONALITY).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div>
                      <div className="col-12"><label className="form-label" htmlFor="bot-bio">Bio pública</label><textarea id="bot-bio" className="form-control" rows={2} maxLength={1000} value={form.about} onChange={(event) => setForm({ ...form, about: event.target.value })} /></div>
                      <div className="col-12"><label className="form-label" htmlFor="bot-interests">Interesses (até 10, separados por vírgula; máximo 40 caracteres cada)</label><input id="bot-interests" className="form-control" value={form.interests} onChange={(event) => setForm({ ...form, interests: event.target.value })} placeholder="Louvor, viagens, café" /></div>
                      <div className="col-12">
                        <label className="form-label">Fotos (1 a 6; JPG, JPEG, PNG ou WEBP; máximo 5 MB)</label>
                        <div className="d-flex gap-2 flex-wrap">
                          {form.photos.map((photo, index) => (
                            <div key={`${photo}-${index}`} className="position-relative">
                              <span className="avatar avatar-xl" style={{ backgroundImage: `url(${photo})` }} />
                              <button type="button" className="btn btn-icon btn-sm btn-danger position-absolute top-0 end-0 translate-middle" aria-label={`Remover foto ${index + 1}`} onClick={() => setForm({ ...form, photos: form.photos.filter((_, itemIndex) => itemIndex !== index) })}>×</button>
                            </div>
                          ))}
                          {form.photos.length < 6 && <button type="button" className="btn btn-icon btn-outline-secondary" aria-label="Adicionar foto" onClick={() => fileRef.current?.click()} style={{ width: 64, height: 64 }}>{formUploading ? <span className="spinner-border spinner-border-sm" aria-hidden="true" /> : <IconPlus size={22} aria-hidden="true" />}</button>}
                        </div>
                        <input ref={fileRef} type="file" accept=".jpg,.jpeg,.png,.webp,image/jpeg,image/png,image/webp" hidden onChange={onPickFile} />
                      </div>

                      <div className="col-12"><hr className="my-1" /></div>
                      <div className="col-12"><div className="d-flex align-items-center gap-2"><IconBrain size={20} className="text-purple" aria-hidden="true" /><div><div className="fw-bold">Cérebro e memória</div><div className="text-secondary small">Os campos vazios herdam a configuração global da página Regras e IA.</div></div></div></div>
                      <div className="col-md-4"><label className="form-check form-switch mt-3"><input className="form-check-input" type="checkbox" checked={form.aiEnabled} onChange={(event) => setForm({ ...form, aiEnabled: event.target.checked })} /><span className="form-check-label">Responder com IA</span></label></div>
                      <div className="col-md-4"><label className="form-check form-switch mt-3"><input className="form-check-input" type="checkbox" checked={form.botMemoryEnabled} disabled={!form.aiEnabled} onChange={(event) => setForm({ ...form, botMemoryEnabled: event.target.checked })} /><span className="form-check-label">Memória de longo prazo</span></label></div>
                      <div className="col-md-4"><label className="form-label" htmlFor="bot-temperature">Criatividade: {Number.isFinite(form.botTemperature) ? form.botTemperature.toFixed(2) : "inválida"}</label><input id="bot-temperature" type="range" min={0} max={2} step={0.05} className="form-range" value={form.botTemperature} onChange={(event) => setForm({ ...form, botTemperature: Number(event.target.value) })} /></div>
                      <div className="col-md-3"><label className="form-label" htmlFor="bot-model-provider">Provider do modelo</label><select id="bot-model-provider" className="form-select" value={form.botAiModelProvider} disabled={!form.botAiModel.trim()} onChange={(event) => setForm({ ...form, botAiModelProvider: event.target.value as AiProvider | "" })}><option value="">Selecione</option><option value="deepseek">DeepSeek</option><option value="openai">OpenAI</option></select><div className="form-hint">Vincula o override ao endpoint correto.</div></div>
                      <div className="col-md-4"><label className="form-label" htmlFor="bot-model">Modelo próprio (opcional)</label><input id="bot-model" className="form-control" value={form.botAiModel} maxLength={100} onChange={(event) => { const botAiModel = event.target.value; setForm({ ...form, botAiModel, botAiModelProvider: botAiModel.trim() ? form.botAiModelProvider : "" }); }} placeholder="Usar modelo global" /><div className="form-hint">Ex.: deepseek-chat. Vazio limpa também o provider.</div>{globalAiProvider && form.botAiModelProvider && form.botAiModelProvider !== globalAiProvider && <div className="alert alert-warning small py-2 mt-2 mb-0">Este override será preservado, mas ficará ignorado enquanto o provider global for {globalAiProvider === "deepseek" ? "DeepSeek" : "OpenAI"}.</div>}</div>
                      <div className="col-md-5"><label className="form-label" htmlFor="bot-prompt">Instrução exclusiva da personalidade</label><textarea id="bot-prompt" className="form-control" rows={4} maxLength={4000} value={form.botSystemPrompt} onChange={(event) => setForm({ ...form, botSystemPrompt: event.target.value })} placeholder="Ex.: acolha com calma, converse sobre fé e faça uma pergunta por vez." /><div className="form-hint d-flex justify-content-between gap-2"><span>A API aplica regras de transparência, segurança e respeito acima desta instrução.</span><span>{form.botSystemPrompt.length}/4000</span></div></div>
                    </div>
                  </fieldset>
                </div>
                <div className="modal-footer"><button type="button" className="btn" disabled={saving || formUploading} onClick={closeForm}>Cancelar</button><button type="button" className="btn btn-primary" disabled={saving || formUploading} aria-busy={saving} onClick={() => void save()}>{saving ? "Salvando..." : formUploading ? "Enviando imagem..." : "Salvar perfil"}</button></div>
              </div>
            </div>
          </div>
          <div className="modal-backdrop fade show" aria-hidden="true" onMouseDown={closeForm} />
        </>
      )}

      {blast && (
        <>
          <div ref={broadcastModalRef} className="modal modal-blur fade show d-block" tabIndex={-1} role="dialog" aria-modal="true" aria-labelledby="broadcast-title">
            <div className="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable" role="document">
              <div className="modal-content">
                <div className="modal-header"><div><div className="text-secondary small">Mensagem iniciada por perfil virtual</div><h5 className="modal-title" id="broadcast-title">Disparar como {blast.fullName}</h5></div><button type="button" className="btn-close" aria-label="Fechar" disabled={blastSending || blastUploading} onClick={closeBroadcast} /></div>
                <div className="modal-body">
                  <div className="alert alert-warning small">O disparo cria ou reativa uma conversa. Use apenas com público que aceitou mensagens de perfis virtuais. Mensagens persistidas não significam entrega push.</div>
                  <fieldset disabled={blastSending || blastUploading || broadcastDraftLocked} className="border-0 m-0 p-0">
                    <div className="row g-3 mb-3">
                      <div className="col-md-7"><label className="form-label" htmlFor="blast-audience">Público</label><select id="blast-audience" className="form-select" data-modal-initial value={blastAudience} onChange={(event) => { setBlastAudience(event.target.value); invalidateBroadcastAttempt(); }}><option value="all">Todos os usuários elegíveis (até 500)</option><option value="free">Somente grátis</option><option value="premium">Somente VIP</option><option value="online">Online agora</option></select></div>
                      <div className="col-md-5"><label className="form-label">Resultado desta tentativa</label><div className="form-control bg-light broadcast-result" role="status" aria-live="polite">{blastResult ? broadcastResultText(blastResult) : activeBroadcastAttempt ? "Tentativa preservada. Consulte ou retome usando a mesma chave." : "Ainda não processada"}</div></div>
                    </div>
                    <label className="form-label" htmlFor="blast-message">Mensagem</label>
                    <div className="position-relative mb-3">
                      <textarea id="blast-message" className="form-control" rows={3} maxLength={500} value={blastText} onChange={(event) => { setBlastText(event.target.value); invalidateBroadcastAttempt(); }} placeholder="Olá! Que bom ter você por aqui 😊" />
                      <div className="d-flex flex-wrap gap-1 mt-2">
                        {EMOJIS.map((emoji) => <button key={emoji} type="button" className="btn btn-sm btn-ghost-secondary" aria-label={`Adicionar emoji ${emoji}`} onClick={() => { setBlastText((value) => value + emoji); invalidateBroadcastAttempt(); }}>{emoji}</button>)}
                        <button type="button" className="btn btn-sm btn-icon btn-ghost-secondary ms-auto" aria-label="Abrir seletor de emojis" onClick={() => setShowEmojiPicker((value) => !value)}><IconMoodSmile size={16} aria-hidden="true" /></button>
                      </div>
                      {showEmojiPicker && <div className="emoji-picker-wrapper"><EmojiPicker width="100%" onEmojiClick={(emoji) => { setBlastText((value) => value + emoji.emoji); invalidateBroadcastAttempt(); setShowEmojiPicker(false); }} /></div>}
                    </div>
                    <label className="form-label" htmlFor="blast-image">Imagem opcional</label>
                    <div className="input-group mb-2"><input id="blast-image" type="url" className="form-control" placeholder="https://..." value={blastImageUrl} onChange={(event) => { setBlastImageUrl(event.target.value); setBlastImage(""); invalidateBroadcastAttempt(); }} /><button type="button" className="btn btn-outline-secondary" onClick={() => blastImageRef.current?.click()}><IconPhoto size={16} className="me-1" aria-hidden="true" />{blastUploading ? "Enviando..." : "Upload"}</button></div>
                    {(blastImage || blastImageUrl) && <div className="position-relative d-inline-block mb-3"><img src={blastImage || blastImageUrl} alt="Prévia do disparo" className="broadcast-preview" /><button type="button" className="btn btn-icon btn-sm btn-danger position-absolute top-0 end-0 translate-middle" aria-label="Remover imagem" onClick={() => { setBlastImage(""); setBlastImageUrl(""); invalidateBroadcastAttempt(); }}>×</button></div>}
                    <input ref={blastImageRef} type="file" accept=".jpg,.jpeg,.png,.webp,image/jpeg,image/png,image/webp" hidden onChange={onPickBlastImage} />
                  </fieldset>

                  <div className="mt-3 border-top pt-3">
                    <div className="d-flex align-items-center justify-content-between gap-2"><span className="form-label mb-0">Histórico recente</span><button type="button" className="btn btn-sm btn-ghost-secondary" disabled={historyLoading || history.length === 0} onClick={() => setShowHistory((value) => !value)}><IconClock size={14} className="me-1" aria-hidden="true" />{showHistory ? "Ocultar" : "Exibir"}</button></div>
                    {historyLoading && <div className="text-secondary small mt-2" role="status"><span className="spinner-border spinner-border-sm me-2" aria-hidden="true" />Carregando histórico...</div>}
                    {historyError && <div className="alert alert-warning retry-state mt-2 mb-0 py-2" role="alert"><span>{historyError}</span><button type="button" className="btn btn-sm" onClick={() => void loadHistory(blast.userId)}>Tentar novamente</button></div>}
                    {!historyLoading && !historyError && history.length === 0 && <div className="text-secondary small mt-2">Nenhum disparo registrado.</div>}
                    {showHistory && history.length > 0 && (
                      <div className="mt-2 broadcast-history">
                        {history.slice(0, 8).map((item) => (
                          <div key={item.id} className="border-bottom py-2 small">
                            <div className="d-flex align-items-center flex-wrap gap-2">
                              {item.status === "FAILED" ? (
                                <IconAlertTriangle size={14} className="text-danger" aria-hidden="true" />
                              ) : item.status === "PENDING" || item.status === "PROCESSING" ? (
                                <IconClock size={14} className="text-warning" aria-hidden="true" />
                              ) : (
                                <IconCheck size={14} className="text-success" aria-hidden="true" />
                              )}
                              <span className={item.status === "FAILED" ? "text-danger" : "text-secondary"}>
                                {item.status === "FAILED" ? "Falhou — retomável" : item.status === "PENDING" || item.status === "PROCESSING" ? "Processando" : formatHistoryDate(item.sentAt)}
                              </span>
                              <span className="badge bg-azure-lt">{safeCount(item.sent)}/{safeCount(item.targeted)} persistidas</span>
                              {safeCount(item.failedCount) > 0 && <span className="badge bg-red-lt">{safeCount(item.failedCount)} falhas</span>}
                              <span className="text-secondary" title={item.idempotencyKey}>tentativa {item.idempotencyKey.slice(0, 8)}…</span>
                            </div>
                            <div className="text-truncate mt-1" title={item.lastError || undefined}>{item.text || "Disparo com imagem"}</div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                </div>
                <div className="modal-footer">
                  <button type="button" className="btn" disabled={blastSending || blastUploading} onClick={closeBroadcast}>Fechar</button>
                  {activeBroadcastAttempt && <button type="button" className="btn btn-outline-danger" disabled={blastSending || blastUploading} onClick={requestNewBroadcast}>Novo disparo</button>}
                  <button type="button" className="btn btn-primary" disabled={blastSending || blastUploading} aria-busy={blastSending} onClick={() => void sendBlast()}><IconSend size={16} className="me-1" aria-hidden="true" />{blastSending ? "Processando..." : blastUploading ? "Enviando imagem..." : activeBroadcastAttempt ? "Consultar / retomar" : "Iniciar disparo"}</button>
                </div>
              </div>
            </div>
          </div>
          <div className="modal-backdrop fade show" aria-hidden="true" onMouseDown={closeBroadcast} />
        </>
      )}

      <Dialog config={dialog} onClose={() => setDialog(null)} />
      <Toast toast={toast} onClose={() => setToast(null)} />
    </>
  );
}
