# meu.painel

Painel administrativo para acompanhar os números do portfólio (visitas, cliques, vídeos vistos e mensagens recebidas). Site estático, sem build e sem Node: é só HTML, CSS e JavaScript puro, com Supabase carregado por CDN.

## Arquivos

- `login.html`: tela de login.
- `painel.html`: painel interno, protegido por login.
- `js/auth.js`: configuração do Supabase e funções de autenticação.
- `setup.sql`: script para criar as tabelas no Supabase.

## Como publicar e criar seu usuário

1. No site do Supabase, abra o seu projeto e vá em **SQL Editor** > **New query**. Cole todo o conteúdo de `setup.sql` e clique em **Run** para criar as tabelas.
2. Ainda no Supabase, vá em **Authentication** > **Users** > **Add user**. Cadastre seu e-mail e uma senha, marcando a opção **Auto Confirm User**. Esse será o login do painel.
3. Para testar localmente antes de publicar, você pode simplesmente dar duplo clique em `login.html` para abrir no navegador (funciona na maioria dos casos). Se algo não carregar direito, abra a pasta com uma extensão de servidor local, como o Live Server do VS Code.
4. Para publicar, suba a pasta `painel` inteira (com `login.html`, `painel.html`, a pasta `js` e os demais arquivos) para o GitHub Pages, do mesmo jeito que você já faz com o site principal, ou arraste a pasta em [vercel.com/new](https://vercel.com/new), que reconhece automaticamente como site estático.
5. Acesse a URL publicada terminando em `/login.html`, entre com o e-mail e a senha criados no passo 2.
6. Guarde bem sua senha. A chave pública (anon) do Supabase já vem no código por padrão do próprio Supabase, mas as tabelas ficam protegidas por Row Level Security, então só quem estiver logado consegue ler os dados.

## Observação sobre os dados

As tabelas `portfolio_events` e `portfolio_leads` precisam ser preenchidas pelo site do portfólio (a cada visita, clique ou envio de formulário). Essa gravação deve ser feita usando a chave de serviço do Supabase no servidor, não pela chave pública direto do navegador do visitante, para evitar que qualquer pessoa envie dados falsos.
