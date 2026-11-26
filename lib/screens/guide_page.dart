import 'package:flutter/material.dart';

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  static const _items = <(String, String)>[
    (
      'Démarrer la journée',
      'Sur l’Accueil, appuie sur « Démarrer » et saisis le fond de caisse (l’argent déjà dans le tiroir). Il faut une journée ouverte pour enregistrer des ventes.'
    ),
    (
      'Faire une vente',
      'Accueil › Nouvelle vente. Ajoute les boissons ou kits avec + et −, choisis Espèces ou Crédit, puis valide. Le stock baisse tout seul. Pour un crédit, choisis le client ou crée-le avec l’icône 👤+.'
    ),
    (
      'Ajouter des boissons',
      'Accueil › Créer boisson : nom, prix d’achat, prix de vente, seuil d’alerte et stock initial. Les kits (casier, cocktail…) se créent dans ☰ › Catalogue kits.'
    ),
    (
      'Recevoir de la marchandise',
      'Accueil › Approvisionnement : saisis la quantité reçue pour chaque boisson. Le stock augmente.'
    ),
    (
      'Faire l’inventaire et repérer les pertes',
      'Accueil › Inventaire (propriétaire) : compte ce qu’il y a vraiment en rayon. Les manques sont enregistrés comme pertes et valorisés au prix d’achat (☰ › Pertes).'
    ),
    (
      'Dépenses et caisse',
      'Accueil › Dépense : indique si elle est payée avec la caisse ou non. L’onglet Caisse montre l’argent qui doit se trouver dans le tiroir.'
    ),
    (
      'Clôturer la journée',
      'Sur l’Accueil, appuie sur « Clôturer », compte l’argent en caisse et saisis-le. L’appli affiche l’écart : manque, excédent ou caisse juste. Le rapport s’imprime depuis le Journal › Clôtures.'
    ),
    (
      'Crédits clients',
      '☰ › Crédits clients : touche un client pour encaisser un paiement, même partiel.'
    ),
    (
      'Imprimer les reçus',
      'Jumelle d’abord l’imprimante dans les réglages Bluetooth du téléphone, puis ☰ › Imprimante pour la choisir et faire un test. Après chaque vente, l’appli propose d’imprimer.'
    ),
    (
      'Journal, graphiques et bilans',
      'L’onglet Journal affiche ventes, dépenses et graphiques sur la période choisie. ☰ › Bénéfices et bilans donne la marge par boisson, les produits dormants et le bilan de stock.'
    ),
    (
      'Exporter les données',
      '☰ › Exports : choisis les données, la période et le format (Excel, CSV ou PDF), puis partage le fichier par WhatsApp ou e-mail.'
    ),
    (
      'Sauvegarder (très important)',
      'L’appli fonctionne sans internet : tes données ne sont que sur ce téléphone. Fais régulièrement ☰ › Sauvegarde et restauration › Créer, et envoie le fichier sur WhatsApp ou Drive. En cas de perte du téléphone, restaure-le sur un autre.'
    ),
    (
      'Plusieurs établissements',
      'Le propriétaire touche le nom de l’établissement dans ☰ pour en changer ou en ajouter un. Chaque établissement a ses propres boissons, stocks, ventes, caisse, clients et serveurs.'
    ),
    (
      'Propriétaire et serveurs',
      'Le propriétaire voit tout. Un serveur, connecté avec son code PIN, peut vendre, saisir des dépenses et voir uniquement ses propres ventes. Crée les serveurs dans ☰ › Utilisateurs.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final it in _items)
          Card(
            child: ExpansionTile(
              title: Text(it.$1),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(it.$2)],
            ),
          ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('Maquis Manager 1.0 · fonctionne 100 % hors ligne',
                style: TextStyle(fontSize: 12, color: Colors.white54)),
          ),
        ),
      ],
    );
  }
}
