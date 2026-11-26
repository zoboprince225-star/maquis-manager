// Déclencheurs SQL : chaque changement important est inscrit automatiquement
// dans la table audit_entries, avec l'utilisateur connecté.

const _on = '(SELECT enabled FROM app_session WHERE id = 1) = 1';
const _me = '(SELECT user_id FROM app_session WHERE id = 1)';

String _trigger({
  required String name,
  required String event,
  required String table,
  required String eid,
  required String action,
  required String entity,
  required String detail,
  String cond = '',
  String? user,
}) {
  final u = user ?? _me;
  final extra = cond.isEmpty ? '' : ' AND ($cond)';
  return '''
CREATE TRIGGER $name AFTER $event ON $table
WHEN $_on$extra
BEGIN
  INSERT INTO audit_entries (establishment_id, user_id, user_name, action, entity, detail)
  VALUES ($eid, $u, (SELECT name FROM users WHERE id = $u), $action, $entity, $detail);
END''';
}

final List<String> auditTriggers = [
  // ---- Boissons ----
  _trigger(
    name: 'trg_audit_drink_ins',
    event: 'INSERT',
    table: 'drinks',
    eid: 'NEW.establishment_id',
    action: "'Création'",
    entity: "'Boisson'",
    detail:
        "'Boisson créée : ' || NEW.name || ' (vente ' || NEW.sale_price || ', achat ' || NEW.purchase_price || ')'",
  ),
  _trigger(
    name: 'trg_audit_drink_upd',
    event: 'UPDATE',
    table: 'drinks',
    eid: 'NEW.establishment_id',
    action: "'Modification'",
    entity: "'Boisson'",
    cond:
        'OLD.is_active = 1 AND NEW.is_active = 1 AND (OLD.name <> NEW.name OR OLD.sale_price <> NEW.sale_price OR OLD.purchase_price <> NEW.purchase_price OR OLD.alert_threshold <> NEW.alert_threshold)',
    detail:
        "'Boisson modifiée : ' || OLD.name"
        " || CASE WHEN OLD.name <> NEW.name THEN ' | nom → ' || NEW.name ELSE '' END"
        " || CASE WHEN OLD.sale_price <> NEW.sale_price THEN ' | vente ' || OLD.sale_price || ' → ' || NEW.sale_price ELSE '' END"
        " || CASE WHEN OLD.purchase_price <> NEW.purchase_price THEN ' | achat ' || OLD.purchase_price || ' → ' || NEW.purchase_price ELSE '' END"
        " || CASE WHEN OLD.alert_threshold <> NEW.alert_threshold THEN ' | seuil ' || OLD.alert_threshold || ' → ' || NEW.alert_threshold ELSE '' END",
  ),
  _trigger(
    name: 'trg_audit_drink_del',
    event: 'UPDATE',
    table: 'drinks',
    eid: 'NEW.establishment_id',
    action: "'Suppression'",
    entity: "'Boisson'",
    cond: 'OLD.is_active = 1 AND NEW.is_active = 0',
    detail: "'Boisson supprimée : ' || OLD.name",
  ),

  // ---- Kits ----
  _trigger(
    name: 'trg_audit_kit_ins',
    event: 'INSERT',
    table: 'kits',
    eid: 'NEW.establishment_id',
    action: "'Création'",
    entity: "'Kit'",
    detail: "'Kit créé : ' || NEW.name || ' (prix ' || NEW.sale_price || ')'",
  ),
  _trigger(
    name: 'trg_audit_kit_del',
    event: 'DELETE',
    table: 'kits',
    eid: 'OLD.establishment_id',
    action: "'Suppression'",
    entity: "'Kit'",
    detail: "'Kit supprimé : ' || OLD.name",
  ),

  // ---- Ventes ----
  _trigger(
    name: 'trg_audit_sale_ins',
    event: 'INSERT',
    table: 'sales',
    eid: 'NEW.establishment_id',
    action: "'Création'",
    entity: "'Vente'",
    user: 'COALESCE(NEW.user_id, $_me)',
    detail:
        "'Vente n°' || NEW.id || ' : ' || NEW.total || ' FCFA (' || CASE NEW.payment_mode WHEN 'credit' THEN 'crédit' ELSE 'espèces' END || ')'",
  ),

  // ---- Dépenses ----
  _trigger(
    name: 'trg_audit_expense_ins',
    event: 'INSERT',
    table: 'expenses',
    eid: 'NEW.establishment_id',
    action: "'Création'",
    entity: "'Dépense'",
    user: 'COALESCE(NEW.user_id, $_me)',
    detail:
        "'Dépense : ' || NEW.label || ' — ' || NEW.amount || ' FCFA (' || CASE NEW.from_cash WHEN 1 THEN 'caisse' ELSE 'hors caisse' END || ')'",
  ),

  // ---- Clients et crédits ----
  _trigger(
    name: 'trg_audit_customer_ins',
    event: 'INSERT',
    table: 'customers',
    eid: 'NEW.establishment_id',
    action: "'Création'",
    entity: "'Client'",
    detail: "'Client créé : ' || NEW.name",
  ),
  _trigger(
    name: 'trg_audit_payment_ins',
    event: 'INSERT',
    table: 'credit_payments',
    eid: 'NEW.establishment_id',
    action: "'Paiement'",
    entity: "'Crédit'",
    user: 'COALESCE(NEW.user_id, $_me)',
    detail:
        "'Paiement de crédit : ' || NEW.amount || ' FCFA de ' || COALESCE((SELECT name FROM customers WHERE id = NEW.customer_id), '?')",
  ),

  // ---- Utilisateurs ----
  _trigger(
    name: 'trg_audit_user_ins',
    event: 'INSERT',
    table: 'users',
    eid: 'NEW.establishment_id',
    action: "'Création'",
    entity: "'Utilisateur'",
    detail:
        "'Utilisateur créé : ' || NEW.name || ' (' || CASE NEW.role WHEN 'owner' THEN 'propriétaire' ELSE 'serveur' END || ')'",
  ),
  _trigger(
    name: 'trg_audit_user_del',
    event: 'DELETE',
    table: 'users',
    eid: 'OLD.establishment_id',
    action: "'Suppression'",
    entity: "'Utilisateur'",
    detail: "'Utilisateur supprimé : ' || OLD.name",
  ),

  // ---- Stock ----
  _trigger(
    name: 'trg_audit_stock_ins',
    event: 'INSERT',
    table: 'stock_movements',
    eid: 'NEW.establishment_id',
    action:
        "CASE NEW.type WHEN 'supply' THEN 'Approvisionnement' WHEN 'loss' THEN 'Perte' ELSE 'Inventaire' END",
    entity: "'Stock'",
    cond: "NEW.type IN ('supply', 'loss', 'inventory')",
    user: 'COALESCE(NEW.user_id, $_me)',
    detail:
        "COALESCE((SELECT name FROM drinks WHERE id = NEW.drink_id), '?') || ' : '"
        " || CASE WHEN NEW.quantity > 0 THEN '+' ELSE '' END || NEW.quantity"
        " || CASE NEW.type WHEN 'loss' THEN ' (valeur ' || (-NEW.quantity * NEW.unit_cost) || ' FCFA)' ELSE '' END"
        " || COALESCE(' — ' || NEW.note, '')",
  ),

  // ---- Journées de travail ----
  _trigger(
    name: 'trg_audit_day_open',
    event: 'INSERT',
    table: 'work_days',
    eid: 'NEW.establishment_id',
    action: "'Ouverture'",
    entity: "'Journée'",
    detail:
        "'Journée démarrée (fond de caisse ' || NEW.opening_cash || ' FCFA)'",
  ),
  _trigger(
    name: 'trg_audit_day_close',
    event: 'UPDATE',
    table: 'work_days',
    eid: 'NEW.establishment_id',
    action: "'Clôture'",
    entity: "'Journée'",
    cond: 'OLD.closed_at IS NULL AND NEW.closed_at IS NOT NULL',
    detail:
        "'Journée clôturée (compté ' || COALESCE(NEW.counted_cash, 0) || ' FCFA)'",
  ),
];
