/* =========================================================================
   AUTENTICAÇÃO COMPARTILHADA (Supabase)
   Este arquivo é carregado tanto por login.html quanto por painel.html.
   Ele cria o cliente Supabase uma única vez e expõe window.Auth com as
   funções de login, logout e verificação de sessão.
========================================================================= */

// EDITE AQUI se um dia precisar trocar de projeto Supabase.
const SUPABASE_URL = "https://pewypiklvucvkvaggbsl.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBld3lwaWtsdnVjdmt2YWdnYnNsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxMTg5NjAsImV4cCI6MjA5OTY5NDk2MH0.gFCm-D_LPe97aqhgp_pxjsEIXVxCPvX1SkCJZdvAl1g";

// Cliente único do Supabase. A variável "sb" fica disponível para qualquer
// script carregado depois deste na mesma página (login.html e painel.html).
const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

window.Auth = {
  // Faz login com e-mail e senha. Em caso de falha, lança um erro com
  // mensagem amigável para mostrar na tela.
  async login(email, senha) {
    const { data, error } = await sb.auth.signInWithPassword({
      email,
      password: senha
    });

    if (error) {
      if (error.message === "Invalid login credentials") {
        throw new Error("E-mail ou senha incorretos.");
      }
      throw new Error(error.message);
    }

    return data.user;
  },

  // Verifica se existe uma sessão ativa. Use no topo de toda página protegida.
  // Se não houver sessão, redireciona para login.html e retorna null.
  async checkAuth() {
    const { data, error } = await sb.auth.getSession();

    if (error || !data.session) {
      window.location.href = "login.html";
      return null;
    }

    return data.session.user;
  },

  // Encerra a sessão atual e volta para a tela de login.
  async logout() {
    await sb.auth.signOut();
    window.location.href = "login.html";
  },

  // Envia e-mail de redefinição de senha.
  async recuperarSenha(email) {
    const { error } = await sb.auth.resetPasswordForEmail(email);
    if (error) {
      throw new Error(error.message);
    }
  }
};
