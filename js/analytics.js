/* =========================================================================
   RASTREAMENTO DE VISITAS (Supabase)
   Este script só GRAVA dados (visitas, cliques, vídeos assistidos e
   mensagens de contato) para o painel administrativo poder ler depois.
   Ele nunca lê nada do banco, e qualquer falha aqui é silenciosa: um
   problema de rede ou do Supabase nunca pode quebrar o site do portfólio.
========================================================================= */

const ANALYTICS_URL = "https://pewypiklvucvkvaggbsl.supabase.co";
const ANALYTICS_KEY = "sb_publishable_wn7_GUN2EdWGaR7n0MBk9g_LgNrLMHT";

let clienteAnalytics = null;
try {
  clienteAnalytics = window.supabase.createClient(ANALYTICS_URL, ANALYTICS_KEY);
} catch (erro) {
  console.warn("Rastreamento desativado (Supabase não carregou):", erro);
}

// Um id por sessão do navegador: dura enquanto a aba estiver aberta e
// identifica visitas repetidas da mesma pessoa como um único "visitante".
function obterSessionId() {
  try {
    let id = sessionStorage.getItem("portfolio_session_id");
    if (!id) {
      id = (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : String(Date.now()) + Math.random();
      sessionStorage.setItem("portfolio_session_id", id);
    }
    return id;
  } catch (erro) {
    // sessionStorage pode falhar em navegação privada; segue sem travar.
    return "sem-sessao";
  }
}

window.PortfolioAnalytics = {
  // Registra um evento (page_view, button_click ou video_view).
  // Usa uma função do banco (rpc) em vez de gravar direto na tabela.
  async registrarEvento(eventType, eventName, metadata) {
    if (!clienteAnalytics) return;
    try {
      await clienteAnalytics.rpc("registrar_evento", {
        p_event_type: eventType,
        p_event_name: eventName || null,
        p_session_id: obterSessionId(),
        p_page_path: window.location.pathname,
        p_metadata: metadata || null
      });
    } catch (erro) {
      console.warn("Não foi possível registrar evento:", erro);
    }
  },

  // Registra uma mensagem de contato (formulário ou pop-up).
  async registrarLead(lead) {
    if (!clienteAnalytics) return;
    try {
      await clienteAnalytics.rpc("registrar_lead", {
        p_name: lead.name || null,
        p_email: lead.email || null,
        p_phone: lead.phone || null,
        p_brand: lead.brand || null,
        p_budget: lead.budget || null,
        p_message: lead.message || null,
        p_source: lead.source || null
      });
    } catch (erro) {
      console.warn("Não foi possível registrar mensagem:", erro);
    }
  }
};
