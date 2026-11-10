// EduGame Hub - Firebase Spark (khong can backend Java/Cloud Run/Cloud Storage).
// Metadata doc tu Firestore, HTML game tu Hosting site rieng de tach origin.
import { initializeApp } from 'https://www.gstatic.com/firebasejs/12.5.0/firebase-app.js';
import { getAuth, GoogleAuthProvider, signInWithPopup, signOut, onAuthStateChanged } from 'https://www.gstatic.com/firebasejs/12.5.0/firebase-auth.js';
import { getFirestore, collection, query, where, getDocs, doc, updateDoc } from 'https://www.gstatic.com/firebasejs/12.5.0/firebase-firestore.js';

const $ = (id) => document.getElementById(id);
const settings = window.EDUGAME_CONFIG || {};
const isValidSlug = (value) => typeof value === 'string' && /^[a-z0-9][a-z0-9-]{0,60}$/.test(value);
let auth = null;
let db = null;
let currentUser = null;
let isAdmin = false;
let games = [];
let adminGames = [];

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}
function notify(element, message) { element.textContent = message || ''; element.hidden = !message; }
function configured() {
  const c = settings.firebaseConfig;
  return !!(c && c.apiKey && c.appId && c.projectId &&
    !String(c.apiKey).startsWith('THAY_') &&
    typeof settings.gamesOrigin === 'string' && /^https:\/\/[a-z0-9-]+\.web\.app$/.test(settings.gamesOrigin));
}
function mapGame(docSnap) {
  const data = docSnap.data();
  if (!isValidSlug(docSnap.id)) return null;
  const slug = docSnap.id;
  return {
    id: slug,
    title: String(data.title || 'Trò chơi').slice(0, 100),
    description: String(data.description || '').slice(0, 800),
    category: String(data.category || 'Khác').slice(0, 80),
    published: data.published === true,
    playUrl: `${settings.gamesOrigin}/play/${slug}.html`,
    downloadUrl: `${settings.gamesOrigin}/download/${slug}.html`
  };
}
async function refreshGames() {
  notify($('errorBanner'), '');
  if (!db) {
    $('gameGrid').innerHTML = '<div class="empty-state">Website chua duoc cau hinh Firebase. Hay chay SETUP-FREE.ps1.</div>';
    $('gameCount').textContent = 'Chưa cấu hình';
    return;
  }
  $('gameGrid').innerHTML = '<div class="empty-state">Đang tải trò chơi...</div>';
  try {
    const snap = await getDocs(query(collection(db, 'games'), where('published', '==', true)));
    games = snap.docs.map(mapGame).filter(Boolean).sort((a, b) => a.title.localeCompare(b.title, 'vi'));
    updateCategories();
    renderGames();
  } catch (err) {
    $('gameCount').textContent = 'Chưa kết nối';
    $('gameGrid').innerHTML = '<div class="empty-state">Không đọc được danh mục trò chơi từ Firestore.</div>';
    notify($('errorBanner'), `Lỗi Firestore: ${err.message}`);
  }
}
function updateCategories() {
  const dropdown = $('categoryFilter');
  const previous = dropdown.value;
  const categories = [...new Set(games.map((g) => g.category))].sort((a, b) => a.localeCompare(b, 'vi'));
  dropdown.replaceChildren(new Option('Tất cả danh mục', ''));
  categories.forEach((c) => dropdown.add(new Option(c, c)));
  dropdown.value = categories.includes(previous) ? previous : '';
}
function renderGames() {
  const keyword = $('searchInput').value.trim().toLocaleLowerCase('vi');
  const category = $('categoryFilter').value;
  const selected = games.filter((g) => (!category || category === g.category) &&
    (!keyword || `${g.title} ${g.description} ${g.category}`.toLocaleLowerCase('vi').includes(keyword)));
  $('gameCount').textContent = `${selected.length} trò chơi`;
  if (!selected.length) {
    $('gameGrid').innerHTML = '<div class="empty-state">Chưa có trò chơi phù hợp.</div>';
    return;
  }
  $('gameGrid').innerHTML = selected.map((g, index) => {
    const duck = /vịt|duck/i.test(g.title);
    const quiz = /đố|hỏi|quiz/i.test(g.title);
    const emoji = duck ? '🦆' : quiz ? '🏆' : ['🚀', '🎮', '🎯', '🏎️', '🧠'][index % 5];
    return `<article class="game-card"><div class="game-art ${duck ? 'duck' : quiz ? 'quiz' : ''}"><span aria-hidden="true">${emoji}</span></div>
      <div class="game-body"><div class="game-badge">${escapeHtml(g.category)}</div><h3>${escapeHtml(g.title)}</h3>
      <p>${escapeHtml(g.description || 'Trò chơi tương tác dành cho lớp học.')}</p>
      <div class="game-actions"><button class="btn btn-primary" data-play="${g.id}">▶ Chơi ngay</button>
      <a class="btn btn-secondary" href="${g.downloadUrl}">↓ Tải về</a></div></div></article>`;
  }).join('');
}
function openGame(id) {
  const game = games.find((g) => g.id === id);
  if (!game) return;
  const target = new URL(game.playUrl);
  // Noi dung game luon phai nam tren hosting site rieng, KHONG cung origin giao dien.
  if (target.protocol !== 'https:' || target.origin === location.origin) {
    notify($('errorBanner'), 'Hosting game chưa tách khỏi website chính. Hãy chạy lại SETUP-FREE.ps1.');
    return;
  }
  $('gameDialogTitle').textContent = game.title;
  $('gameFrame').src = target.href;
  $('openNewTab').href = target.href;
  $('gameDialog').showModal();
}
async function refreshAdminGames() {
  if (!isAdmin) return;
  try {
    const snap = await getDocs(collection(db, 'games'));
    adminGames = snap.docs.map(mapGame).filter(Boolean);
    $('adminList').innerHTML = '<h3>Game đã đăng</h3>' +
      (adminGames.length ? adminGames.map((g) => `<div class="admin-game"><strong>${escapeHtml(g.title)} — ${g.published ? 'Công khai' : 'Ẩn khỏi danh mục'}</strong>
      <span><button type="button" data-toggle="${g.id}">${g.published ? 'Ẩn khỏi danh mục' : 'Hiện lại'}</button></span></div>`).join('') : '<p>Chưa có game. Dùng PUBLISH-GAME.ps1 để xuất bản.</p>');
  } catch (err) { notify($('adminStatus'), 'Không tải được danh sách Admin: ' + err.message); }
}
function initialize() {
  if (!configured()) {
    $('authState').textContent = 'Chưa cấu hình Firebase. Hãy chạy SETUP-FREE.ps1.';
    $('loginBtn').disabled = true;
    refreshGames();
    return;
  }
  try {
    const app = initializeApp(settings.firebaseConfig);
    db = getFirestore(app);
    auth = getAuth(app);
    onAuthStateChanged(auth, async (user) => {
      currentUser = user;
      isAdmin = !!(user && user.emailVerified && user.email?.toLowerCase() === settings.adminEmail?.toLowerCase());
      $('loginBtn').hidden = !!user;
      $('logoutBtn').hidden = !user;
      $('adminHelp').hidden = !isAdmin;
      $('adminList').replaceChildren();
      if (!user) $('authState').textContent = 'Đăng nhập Google để kiểm tra quyền quản trị.';
      else if (!isAdmin) $('authState').textContent = `Tài khoản ${user.email || ''} không phải Admin của website.`;
      else {
        $('authState').textContent = '✓ Đã đăng nhập Admin: ' + user.email;
        await refreshAdminGames();
      }
    });
    refreshGames();
  } catch (err) {
    notify($('errorBanner'), 'Khởi tạo Firebase thất bại: ' + err.message);
  }
}
$('gameGrid').addEventListener('click', (ev) => {
  const btn = ev.target.closest('[data-play]');
  if (btn) openGame(btn.dataset.play);
});
$('searchInput').addEventListener('input', renderGames);
$('categoryFilter').addEventListener('change', renderGames);
$('refreshBtn').addEventListener('click', refreshGames);
$('adminToggle').addEventListener('click', () => $('adminDialog').showModal());
$('closeAdmin').addEventListener('click', () => $('adminDialog').close());
$('closeGame').addEventListener('click', () => $('gameDialog').close());
$('gameDialog').addEventListener('close', () => { $('gameFrame').src = 'about:blank'; });
$('loginBtn').addEventListener('click', async () => {
  if (!auth) return;
  try { notify($('adminStatus'), ''); await signInWithPopup(auth, new GoogleAuthProvider()); }
  catch (err) { notify($('adminStatus'), 'Đăng nhập thất bại: ' + err.message); }
});
$('logoutBtn').addEventListener('click', async () => {
  if (!auth) return;
  try { await signOut(auth); } catch (err) { notify($('adminStatus'), err.message); }
});
$('adminList').addEventListener('click', async (ev) => {
  const btn = ev.target.closest('[data-toggle]');
  if (!btn || !isAdmin || !currentUser) return;
  const selected = adminGames.find((g) => g.id === btn.dataset.toggle);
  if (!selected) return;
  btn.disabled = true;
  try {
    await updateDoc(doc(db, 'games', selected.id), { published: !selected.published });
    notify($('adminStatus'), 'Đã cập nhật danh mục. Lưu ý: URL trực tiếp của file HTML vẫn có thể truy cập.');
    await Promise.all([refreshGames(), refreshAdminGames()]);
  } catch (err) { notify($('adminStatus'), 'Không cập nhật được: ' + err.message); }
  finally { btn.disabled = false; }
});
initialize();
