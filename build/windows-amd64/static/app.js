let modules = [];
let currentModuleId = null;
let selectedItemIds = new Set();
let resultsCache = {};
let draggedNode = null;

async function api(method, path, body) {
  const opts = { method, headers: { 'Content-Type': 'application/json' } };
  if (body) opts.body = JSON.stringify(body);
  const resp = await fetch(path, opts);
  return resp.json();
}

function setStatus(text, state) {
  document.getElementById('statusText').textContent = text;
  const ind = document.getElementById('statusIndicator');
  ind.className = 'status-indicator' + (state ? ' ' + state : '');
}

function log(msg) {
  document.getElementById('tailText').textContent = msg;
}

function esc(s) {
  const div = document.createElement('div');
  div.textContent = s || '';
  return div.innerHTML;
}

async function loadModules() {
  modules = await api('GET', '/api/modules');
  renderTree();
}

async function loadItems(moduleId) {
  currentModuleId = moduleId;
  const items = await api('GET', '/api/items?module_id=' + moduleId);
  renderItems(items);
}

function renderTree() {
  const el = document.getElementById('moduleTree');
  el.oncontextmenu = function(e) { showTreeContextMenu(e); };
  if (!modules.length) {
    el.innerHTML = '<div class="tree-empty">暂无模块</div>';
    return;
  }
  const roots = modules.filter(m => m.parent_id === 0);
  let html = '';
  for (const r of roots) {
    html += renderTreeNode(r, 0);
  }
  el.innerHTML = html;
}

function renderTreeNode(m, depth) {
  const children = modules.filter(c => c.parent_id === m.id);
  const active = currentModuleId === m.id ? ' active' : '';
  const hasChildren = children.length > 0;
  const padLeft = 12 + depth * 16;
  let html = '<div class="tree-node" data-module-id="' + m.id + '">';
  html += '<div class="tree-node-header' + active + '" style="padding-left:' + padLeft + 'px"';
  html += ' draggable="true"';
  html += ' onclick="selectModule(' + m.id + ')"';
  html += ' oncontextmenu="showContextMenu(event,' + m.id + ')"';
  html += ' ondragstart="onDragStart(event,' + m.id + ',\'module\')"';
  html += ' ondragover="onDragOver(event)"';
  html += ' ondrop="onDrop(event,' + m.id + ',\'module\')"';
  html += ' ondragleave="onDragLeave(event)"';
  html += '>';
  html += '<span class="arrow' + (hasChildren ? '' : '" style="visibility:hidden') + '" id="arrow-' + m.id + '" onclick="event.stopPropagation();toggleModuleChildren(' + m.id + ')">▶</span>';
  html += '<span class="icon">📁</span>';
  html += '<span class="name">' + esc(m.name) + '</span>';
  html += '<span class="badge" id="badge-' + m.id + '"></span>';
  html += '</div>';
  if (hasChildren) {
    html += '<div class="tree-node-children" id="children-' + m.id + '">';
    for (const c of children) {
      html += renderTreeNode(c, depth + 1);
    }
    html += '</div>';
  }
  html += '</div>';
  return html;
}

function toggleModuleChildren(moduleId) {
  const arrow = document.getElementById('arrow-' + moduleId);
  const children = document.getElementById('children-' + moduleId);
  if (!arrow || !children) return;
  if (children.classList.contains('expanded')) {
    children.classList.remove('expanded');
    arrow.classList.remove('expanded');
  } else {
    children.classList.add('expanded');
    arrow.classList.add('expanded');
  }
}

async function loadBadges() {
  for (const m of modules) {
    const items = await api('GET', '/api/items?module_id=' + m.id);
    const badge = document.getElementById('badge-' + m.id);
    if (badge) badge.textContent = items.length;
  }
}

function getModuleItemCount(moduleId) {
  const items = document.querySelectorAll('#itemList .item-row');
  return items.length;
}

function selectModule(moduleId) {
  currentModuleId = moduleId;
  document.querySelectorAll('.tree-node-header.active').forEach(e => e.classList.remove('active'));
  const header = document.querySelector('.tree-node-header[onclick*="' + moduleId + '"]') ||
    document.querySelector('.tree-node[data-module-id="' + moduleId + '"] > .tree-node-header');
  if (header) header.classList.add('active');

  loadItems(moduleId);
  hideContextMenu();
}

async function renderItems(items) {
  const el = document.getElementById('itemList');
  if (!items.length) {
    el.innerHTML = '<div class="empty-state">该模块下暂无检测项</div>';
    return;
  }
  const protoLabels = { tcp: 'TCP', http: 'HTTP', udp: 'UDP' };
  const typeLabels = { full: '全探测', regular: '常规' };
  let html = '';
  for (const it of items) {
    const checked = selectedItemIds.has(it.id) ? 'checked' : '';
    const bg = selectedItemIds.has(it.id) ? ' style="background:#e6f7ff"' : '';
    html += '<div class="item-row" data-id="' + it.id + '"' + bg;
    html += ' draggable="true"';
    html += ' ondragstart="onDragStart(event,' + it.id + ',\'item\')"';
    html += ' ondragover="onDragOver(event)"';
    html += ' ondrop="onDrop(event,' + it.id + ',\'item\')"';
    html += ' ondragleave="onDragLeave(event)"';
    html += '>';
    html += '<label class="item-checkbox checkbox-all"><input type="checkbox" ' + checked + ' onchange="toggleItem(' + it.id + ')"></label>';
    html += '<span class="item-address">' + esc(it.address) + '</span>';
    html += '<span class="item-protocol">' + (protoLabels[it.protocol] || it.protocol) + '</span>';
    html += '<span class="item-type">' + (typeLabels[it.probe_type] || it.probe_type) + '</span>';
    html += '<span class="item-cert">' + (it.cert_name ? '✓自定义' : '系统') + '</span>';
    html += '<span class="item-actions"><button class="edit-btn" onclick="event.stopPropagation();showEditItemModal(' + it.id + ')">编辑</button></span>';
    html += '<span class="header-result"></span>';
    html += '</div>';
    html += '<div class="inline-result" id="inline-result-' + it.id + '" style="display:none;"></div>';
    html += '<div class="inline-detail" id="inline-detail-' + it.id + '" style="display:none;"></div>';
  }
  el.innerHTML = html;
}

function toggleItem(id) {
  if (selectedItemIds.has(id)) selectedItemIds.delete(id);
  else selectedItemIds.add(id);
  const row = document.querySelector('.item-row[data-id="' + id + '"]');
  if (row) {
    row.style.background = selectedItemIds.has(id) ? '#e6f7ff' : '';
  }
}

function toggleSelectAll() {
  const checked = document.getElementById('selectAll').checked;
  document.querySelectorAll('.item-row input[type="checkbox"]').forEach(cb => {
    cb.checked = checked;
    const id = parseInt(cb.closest('.item-row').dataset.id);
    if (checked) selectedItemIds.add(id);
    else selectedItemIds.delete(id);
    cb.closest('.item-row').style.background = checked ? '#e6f7ff' : '';
  });
}

function showAddModuleModal(parentID) {
  const m = document.getElementById('modalContent');
  const isSub = parentID ? ' (子模块)' : '';
  m.innerHTML = `
    <h2>添加模块${isSub}</h2>
    <div class="form-group"><label>模块名称</label><input id="modName" placeholder="请输入模块名称"></div>
    <div class="form-group"><label>描述（可选）</label><input id="modDesc" placeholder="模块描述"></div>
    ${parentID ? '<input type="hidden" id="modParent" value="' + parentID + '">' : ''}
    <div class="form-actions">
      <button class="btn btn-cancel" onclick="closeModal()">取消</button>
      <button class="btn btn-primary" onclick="confirmAddModule(${parentID || 0})">确定</button>
    </div>`;
  document.getElementById('modalOverlay').classList.remove('hidden');
  document.getElementById('modName').focus();
}

async function confirmAddModule(parentID) {
  const name = document.getElementById('modName').value.trim();
  if (!name) return;
  const desc = document.getElementById('modDesc').value.trim();
  await api('POST', '/api/modules', { name, description: desc, parent_id: parentID || 0 });
  closeModal();
  await loadModules();
  await loadBadges();
  log('已添加模块: ' + name);
}

async function deleteModule(id) {
  hideContextMenu();
  if (!confirm('确定删除此模块及其所有子模块和检测项？')) return;
  await api('DELETE', '/api/modules/' + id);
  if (currentModuleId === id) {
    currentModuleId = null;
    document.getElementById('itemList').innerHTML = '';
  }
  await loadModules();
  await loadBadges();
  log('已删除模块');
}

function showAddItemModal(moduleID) {
  hideContextMenu();
  if (!modules.length) { alert('请先添加模块'); return; }
  const m = document.getElementById('modalContent');
  let modOpts = modules.map(m =>
    '<option value="' + m.id + '"' + (m.id === (moduleID || currentModuleId) ? ' selected' : '') + '>' + esc(m.name) + '</option>'
  ).join('');
  m.innerHTML = `
    <h2>添加检测项</h2>
    <div class="form-group">
      <label>所属模块</label>
      <select id="itemModule">${modOpts}</select>
    </div>
    <div class="form-group"><label>探测地址</label><input id="itemAddress" placeholder="如: example.com:443 或 https://example.com"></div>
    <div class="form-group">
      <label>探测协议</label>
      <select id="itemProtocol"><option value="http">HTTP</option><option value="tcp">TCP</option><option value="udp">UDP</option></select>
    </div>
    <div class="form-group">
      <label>探测类型</label>
      <select id="itemType"><option value="full">全探测（所有解析IP）</option><option value="regular">常规探测（单个IP）</option></select>
    </div>
    <div class="form-group"><label>自定义证书（可选，PEM格式）</label><textarea id="itemCert" placeholder="粘贴PEM格式证书内容"></textarea></div>
    <div class="form-actions">
      <button class="btn btn-cancel" onclick="closeModal()">取消</button>
      <button class="btn btn-primary" onclick="confirmAddItem()">确定</button>
    </div>`;
  document.getElementById('modalOverlay').classList.remove('hidden');
}

async function confirmAddItem() {
  const moduleId = parseInt(document.getElementById('itemModule').value);
  const address = document.getElementById('itemAddress').value.trim();
  if (!address) return;
  const protocol = document.getElementById('itemProtocol').value;
  const probeType = document.getElementById('itemType').value;
  const certData = document.getElementById('itemCert').value.trim();
  const body = { module_id: moduleId, address, protocol, probe_type: probeType };
  if (certData) { body.cert_name = 'custom.pem'; body.cert_data = certData; }
  await api('POST', '/api/items', body);
  closeModal();
  if (currentModuleId === moduleId) await loadItems(moduleId);
  await loadBadges();
  log('已添加检测项: ' + address);
}

async function showEditItemModal(itemId) {
  const item = await api('GET', '/api/items/' + itemId);
  if (!item || !item.id) return;
  const protoLabels = { tcp: 'TCP', http: 'HTTP', udp: 'UDP' };
  const typeLabels = { full: '全探测', regular: '常规' };
  const curProto = item.protocol || 'http';
  const curType = item.probe_type || 'full';
  const hasCert = !!item.cert_name;
  const m = document.getElementById('modalContent');
  m.innerHTML = `
    <h2>编辑检测项</h2>
    <input type="hidden" id="editItemId" value="${itemId}">
    <div class="form-group"><label>探测地址</label><input id="editAddress" value="${esc(item.address)}"></div>
    <div class="form-group">
      <label>探测协议</label>
      <select id="editProtocol">
        <option value="http"${curProto==='http'?' selected':''}>HTTP</option>
        <option value="tcp"${curProto==='tcp'?' selected':''}>TCP</option>
        <option value="udp"${curProto==='udp'?' selected':''}>UDP</option>
      </select>
    </div>
    <div class="form-group">
      <label>探测类型</label>
      <select id="editType">
        <option value="full"${curType==='full'?' selected':''}>全探测（所有解析IP）</option>
        <option value="regular"${curType==='regular'?' selected':''}>常规探测（单个IP）</option>
      </select>
    </div>
    <div class="form-group"><label>自定义证书（PEM格式，留空使用系统证书）</label><textarea id="editCert" placeholder="粘贴PEM格式证书内容">${esc(item.cert_data || '')}</textarea></div>
    <div class="form-group">${hasCert ? '<label><input type="checkbox" id="clearCert"> 清除自定义证书（改用系统证书）</label>' : ''}</div>
    <div class="form-actions">
      <button class="btn btn-cancel" onclick="closeModal()">取消</button>
      <button class="btn btn-primary" onclick="confirmEditItem()">保存</button>
    </div>`;
  document.getElementById('modalOverlay').classList.remove('hidden');
}

async function confirmEditItem() {
  const id = parseInt(document.getElementById('editItemId').value);
  const address = document.getElementById('editAddress').value.trim();
  if (!address) return;
  const protocol = document.getElementById('editProtocol').value;
  const probeType = document.getElementById('editType').value;
  const certData = document.getElementById('editCert').value.trim();
  const clearCertEl = document.getElementById('clearCert');
  const clearCert = clearCertEl ? clearCertEl.checked : false;
  const body = { address, protocol, probe_type: probeType };
  if (certData) {
    body.cert_name = 'custom.pem';
    body.cert_data = certData;
  } else if (clearCert) {
    body.clear_cert = true;
  }
  await api('PUT', '/api/items/' + id, body);
  closeModal();
  if (currentModuleId) await loadItems(currentModuleId);
  await loadBadges();
  log('已更新检测项: ' + address);
}

function showImportModal() {
  if (!modules.length) { alert('请先添加模块'); return; }
  window.__importItems = [];
  const m = document.getElementById('modalContent');
  let modOpts = modules.map(mod =>
    '<option value="' + mod.id + '"' + (mod.id === currentModuleId ? ' selected' : '') + '>' + esc(mod.name) + '</option>'
  ).join('');
  m.innerHTML = `
    <h2>批量导入检测项</h2>
    <div class="form-group">
      <label>所属模块</label>
      <select id="impModule">${modOpts}</select>
    </div>
    <div class="form-group">
      <label>探测协议</label>
      <select id="impProtocol"><option value="http">HTTP</option><option value="tcp">TCP</option><option value="udp">UDP</option></select>
    </div>
    <div class="form-group">
      <label>探测类型</label>
      <select id="impType"><option value="full">全探测（所有解析IP）</option><option value="regular">常规探测（单个IP）</option></select>
    </div>
    <div class="form-group">
      <label>选择CSV文件（4列：探测地址,协议,探测类型,根证书）</label>
      <div style="display:flex;align-items:center;gap:8px;">
        <input type="file" id="impFile" accept=".csv" style="display:none;">
        <button class="btn btn-sm" style="background:#1890ff;color:#fff;cursor:pointer;" onclick="document.getElementById('impFile').click()">选择文件</button>
        <span id="impFileName" style="color:#999;font-size:12px;"></span>
      </div>
    </div>
    <div class="form-group">
      <label>地址列表（可手动编辑，每行一个地址）</label>
      <textarea id="impAddresses" placeholder="选择CSV文件自动填充，或直接粘贴地址，每行一个"></textarea>
    </div>
    <div class="form-actions">
      <button class="btn btn-sm" style="background:#722ed1;color:#fff;" onclick="downloadTemplate()">下载模板</button>
      <button class="btn btn-cancel" onclick="closeModal()">取消</button>
      <button class="btn btn-primary" onclick="confirmImport()">导入</button>
    </div>`;
  document.getElementById('modalOverlay').classList.remove('hidden');
  document.getElementById('impFile').addEventListener('change', function(e) {
    const file = e.target.files[0];
    if (!file) return;
    document.getElementById('impFileName').textContent = file.name;
    const reader = new FileReader();
    reader.onload = function(ev) {
      const text = ev.target.result;
      const items = [];
      const rows = text.split('\n').map(s => s.trim()).filter(s => s);
      for (let i = 1; i < rows.length; i++) {
        const cols = parseCSVLine(rows[i]);
        if (cols.length > 0 && cols[0]) {
          const item = { address: cols[0] };
          if (cols.length >= 4 && cols[3].trim()) {
            item.cert_data = cols[3];
            item.cert_name = 'custom.pem';
          }
          items.push(item);
        }
      }
      window.__importItems = items;
      document.getElementById('impAddresses').value = items.map(it => it.address).join('\n');
    };
    reader.readAsText(file);
  });
}

function parseCSVLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (inQuotes) {
      if (ch === '"' && line[i + 1] === '"') { current += '"'; i++; }
      else if (ch === '"') { inQuotes = false; }
      else { current += ch; }
    } else {
      if (ch === '"') { inQuotes = true; }
      else if (ch === ',') { result.push(current.trim()); current = ''; }
      else { current += ch; }
    }
  }
  result.push(current.trim());
  return result;
}

async function confirmImport() {
  const moduleId = parseInt(document.getElementById('impModule').value);
  const defaultProtocol = document.getElementById('impProtocol').value;
  const defaultProbeType = document.getElementById('impType').value;
  const text = document.getElementById('impAddresses').value.trim();
  if (!text) return;
  const lines = text.split('\n').map(s => s.trim()).filter(s => s);

  let items;
  if (window.__importItems && window.__importItems.length === lines.length) {
    items = window.__importItems;
  } else {
    items = lines.map(addr => ({ address: addr }));
  }

  await api('POST', '/api/items/import', {
    module_id: moduleId,
    protocol: defaultProtocol,
    probe_type: defaultProbeType,
    items: items
  });
  window.__importItems = [];
  closeModal();
  if (currentModuleId === moduleId) await loadItems(moduleId);
  await loadBadges();
  log('已导入 ' + items.length + ' 个检测项');
}

async function startDetection() {
  if (!selectedItemIds.size) { alert('请先勾选需要探测的检测项'); return; }

  setStatus('探测中...', 'busy');
  log('正在探测 ' + selectedItemIds.size + ' 个检测项...');

  for (const id of selectedItemIds) {
    const resultEl = document.getElementById('inline-result-' + id);
    const detailEl = document.getElementById('inline-detail-' + id);
    if (resultEl) {
      resultEl.style.display = 'block';
      resultEl.innerHTML = '<span style="color:#999;">探测中...</span>';
    }
    if (detailEl) detailEl.style.display = 'none';
  }

  try {
    const itemIds = Array.from(selectedItemIds);
    const resultsData = await api('POST', '/api/detect', { item_ids: itemIds });

    for (const res of resultsData) {
      showInlineResult(res);
    }
    setStatus('探测完成', '');
    log('探测完成: 共 ' + resultsData.length + ' 项');
  } catch (err) {
    setStatus('探测失败', 'error');
    log('探测失败: ' + err.message);
    for (const id of selectedItemIds) {
      const resultEl = document.getElementById('inline-result-' + id);
      if (resultEl) {
        resultEl.innerHTML = '<span style="color:#ff4d4f;">探测失败: ' + esc(err.message) + '</span>';
      }
    }
  }
}

function getOverallStatus(results) {
  const ok = results.filter(r => r.status === 0).length;
  const fail = results.filter(r => r.status !== 0).length;
  const total = results.length;
  if (ok === total) return 'success';
  if (fail === total) return 'fail';
  return 'partial';
}

function showInlineResult(res) {
  const el = document.getElementById('inline-result-' + res.item_id);
  if (!el) return;
  el.style.display = 'block';

  resultsCache[res.item_id] = res;

  const statusClass = getOverallStatus(res.results);
  const okCount = res.results.filter(r => r.status === 0).length;
  const failCount = res.results.filter(r => r.status !== 0).length;

  let statusLabel = '全部成功';
  let statusColor = '#52c41a';
  if (statusClass === 'fail') { statusLabel = '全部失败'; statusColor = '#ff4d4f'; }
  else if (statusClass === 'partial') { statusLabel = '部分成功(' + okCount + '/' + res.results.length + ')'; statusColor = '#fa8c16'; }

  const dnsAvg = (res.results.reduce((s, r) => s + r.dns_cost_ms, 0) / res.results.length).toFixed(2);
  const connAvg = (res.results.reduce((s, r) => s + r.connect_cost_ms, 0) / res.results.length).toFixed(2);
  const fpAvg = (res.results.reduce((s, r) => s + r.first_packet_cost_ms, 0) / res.results.length).toFixed(2);
  const totalAvg = (res.results.reduce((s, r) => s + r.total_cost_ms, 0) / res.results.length).toFixed(2);

  const firstWithCert = res.results.find(r => r.cert_subject);
  let certInfo = '';
  if (firstWithCert) {
    const certVerified = firstWithCert.cert_verified;
    const certColor = certVerified ? '#52c41a' : '#fa8c16';
    const certLabel = certVerified ? '已验证' : '未验证';
    certInfo = '<span class="metric">证书 <span class="value" style="color:' + certColor + ';">' + certLabel + '</span></span>';
  }

  el.innerHTML = `
    <div class="metric-row">
      <span class="metric"><span class="dot ${statusClass}"></span></span>
      <span class="metric" style="font-weight:600;color:${statusColor};">${statusLabel}</span>
      <span class="metric">DNS <span class="value">${dnsAvg}ms</span></span>
      <span class="metric">连接 <span class="value">${connAvg}ms</span></span>
      <span class="metric">首包 <span class="value">${fpAvg}ms</span></span>
      <span class="metric">总耗时 <span class="value">${totalAvg}ms</span></span>
      ${certInfo}
      <span class="result-actions">
        <button class="detail-btn" onclick="toggleDetail(${res.item_id})">详情</button>
      </span>
    </div>`;

  const row = document.querySelector('.item-row[data-id="' + res.item_id + '"]');
  if (row) {
    const statusSpan = row.querySelector('.header-result');
    if (statusSpan) {
      statusSpan.innerHTML = '<span class="dot ' + statusClass + '" style="display:inline-block;width:6px;height:6px;border-radius:50%;"></span> ' +
        '<span style="color:' + statusColor + ';font-weight:600;">' + statusLabel + '</span>' +
        ' <span class="detail-btn" onclick="event.stopPropagation();toggleDetail(' + res.item_id + ')">详情</span>';
    }
  }
}

function toggleDetail(itemId) {
  const el = document.getElementById('inline-detail-' + itemId);
  if (!el) return;
  if (el.style.display !== 'none') {
    el.style.display = 'none';
    const btn = document.querySelector('.detail-btn[onclick*="' + itemId + '"]');
    if (btn) btn.textContent = '详情 ▸';
    return;
  }

  const res = resultsCache[itemId];
  if (!res) return;

  function formatDate(d) {
    if (!d) return '';
    const date = new Date(d);
    return date.toLocaleDateString('zh-CN');
  }

  let html = '';
  for (const sr of res.results) {
    const ok = sr.status === 0;
    html += '<div class="detail-item">';
    html += '<span class="dip">' + esc(sr.ip) + '</span>';
    html += '<span class="dstatus ' + (ok ? 'success' : 'fail') + '">' + (ok ? '✓' : '✗') + '</span>';
    html += '<span class="dmetrics">';
    html += '<span>DNS: ' + sr.dns_cost_ms.toFixed(2) + 'ms</span>';
    html += '<span>连接: ' + sr.connect_cost_ms.toFixed(2) + 'ms</span>';
    html += '<span>首包: ' + sr.first_packet_cost_ms.toFixed(2) + 'ms</span>';
    html += '<span>总耗时: ' + sr.total_cost_ms.toFixed(2) + 'ms</span>';
    if (sr.status_code) html += '<span>状态码: ' + sr.status_code + '</span>';
    html += '</span>';
    html += '</div>';

    if (sr.cert_subject) {
      const certStatus = sr.cert_verified ? '<span style="color:#52c41a;">✓ 已验证</span>' : '<span style="color:#fa8c16;">⚠ 未验证</span>';
      html += '<div class="dcert">';
      html += '<span>证书主体: ' + esc(sr.cert_subject) + '</span>';
      html += '<span>颁发者: ' + esc(sr.cert_issuer) + '</span>';
      html += '<span>有效期: ' + formatDate(sr.cert_not_before) + ' ~ ' + formatDate(sr.cert_not_after) + '</span>';
      html += '<span>状态: ' + certStatus + '</span>';
      html += '</div>';
    }

    if (!ok && sr.error_message) {
      html += '<div style="padding-left:138px;color:#ff4d4f;font-size:11px;margin-bottom:4px;">错误: ' + esc(sr.error_message) + '</div>';
    }
    if (sr.details) {
      html += '<div style="padding-left:138px;color:#666;font-size:11px;margin-bottom:4px;">' + esc(sr.details) + '</div>';
    }
  }
  el.innerHTML = html;
  el.style.display = 'block';

  const btn = document.querySelector('.detail-btn[onclick*="' + itemId + '"]');
  if (btn) btn.textContent = '详情 ▾';
}

async function deleteSelected() {
  if (!selectedItemIds.size) { alert('请先勾选要删除的检测项'); return; }
  if (!confirm('确定删除选中的 ' + selectedItemIds.size + ' 个检测项？')) return;
  const ids = Array.from(selectedItemIds);
  for (const id of ids) {
    await api('DELETE', '/api/items/' + id);
  }
  selectedItemIds.clear();
  document.getElementById('selectAll').checked = false;
  if (currentModuleId) {
    await loadItems(currentModuleId);
    await loadBadges();
  }
  log('已删除 ' + ids.length + ' 个检测项');
}

function downloadTemplate() {
  const a = document.createElement('a');
  a.href = '/static/import_template.csv';
  a.download = 'import_template.csv';
  a.click();
  log('已下载导入模板');
}

function closeModal(e) {
  if (e && e.target !== document.getElementById('modalOverlay')) return;
  document.getElementById('modalOverlay').classList.add('hidden');
}

// --- Context Menu ---
function showContextMenu(event, moduleId) {
  event.preventDefault();
  event.stopPropagation();
  const menu = document.getElementById('contextMenu');
  menu.innerHTML = `
    <div class="menu-item" onclick="showAddSubModule(${moduleId})">添加子模块</div>
    <div class="menu-item" onclick="showAddItemModal(${moduleId})">添加检测项</div>
    <div class="menu-item danger" onclick="deleteModule(${moduleId})">删除模块</div>`;
  menu.style.left = event.clientX + 'px';
  menu.style.top = event.clientY + 'px';
  menu.classList.remove('hidden');
}

function showTreeContextMenu(event) {
  event.preventDefault();
  event.stopPropagation();
  const menu = document.getElementById('contextMenu');
  menu.innerHTML = `
    <div class="menu-item" onclick="showAddModuleModal(0)">添加一级模块</div>`;
  menu.style.left = event.clientX + 'px';
  menu.style.top = event.clientY + 'px';
  menu.classList.remove('hidden');
}

function hideContextMenu() {
  document.getElementById('contextMenu').classList.add('hidden');
}

function showAddSubModule(parentID) {
  hideContextMenu();
  showAddModuleModal(parentID);
}

document.addEventListener('click', function(e) {
  if (!e.target.closest('.context-menu')) hideContextMenu();
});

// --- Drag & Drop ---
function onDragStart(event, id, type) {
  draggedNode = { id, type };
  event.dataTransfer.effectAllowed = 'move';
  event.dataTransfer.setData('text/plain', type + ':' + id);
}

function onDragOver(event) {
  event.preventDefault();
  event.dataTransfer.dropEffect = 'move';
  event.currentTarget.classList.add('drag-over');
}

function onDragLeave(event) {
  event.currentTarget.classList.remove('drag-over');
}

async function onDrop(event, targetId, targetType) {
  event.preventDefault();
  event.currentTarget.classList.remove('drag-over');
  if (!draggedNode) return;

  const srcType = draggedNode.type;
  const srcId = draggedNode.id;
  draggedNode = null;

  if (srcType === 'module' && targetType === 'module') {
    if (srcId === targetId) return;
    if (isDescendant(srcId, targetId)) return;
    await api('PUT', '/api/modules/' + srcId, { parent_id: targetId });
    await loadModules();
    await loadBadges();
    log('已移动模块');
  } else if (srcType === 'item' && targetType === 'module') {
    await api('PUT', '/api/items/move?id=' + srcId, { module_id: targetId });
    if (currentModuleId) await loadItems(currentModuleId);
    await loadBadges();
    log('已移动检测项');
  }
}

function isDescendant(moduleId, targetId) {
  const children = modules.filter(m => m.parent_id === moduleId);
  if (children.find(c => c.id === targetId)) return true;
  for (const c of children) {
    if (isDescendant(c.id, targetId)) return true;
  }
  return false;
}

document.addEventListener('DOMContentLoaded', async () => {
  await loadModules();
  const allItems = await api('GET', '/api/items');
  const counts = {};
  for (const it of allItems) {
    counts[it.module_id] = (counts[it.module_id] || 0) + 1;
  }
  for (const m of modules) {
    const badge = document.getElementById('badge-' + m.id);
    if (badge) badge.textContent = counts[m.id] || 0;
  }
  if (modules.length) {
    currentModuleId = modules[0].id;
    await loadItems(currentModuleId);
    const header = document.querySelector('.tree-node[data-module-id="' + currentModuleId + '"] > .tree-node-header');
    if (header) header.classList.add('active');
  }
  log('就绪 - 选择模块或检测项后开始探测');
});
