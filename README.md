```markdown
# MonEA9 - Expert Advisor pour MetaTrader 5

## Description
MonEA9 est un Expert Advisor (EA) avancé pour MetaTrader 5, conçu pour exploiter les cassures de la fourchette de volatilité de la session asiatique (00h00-06h00 GMT). La stratégie combine des filtres techniques rigoureux (tendance, volatilité, momentum) avec une gestion des risques proactive incluant des protections contre le drawdown et des mécanismes de trailing stop.

## Stratégie de Trading
L'EA identifie la fourchette de prix (High/Low) formée pendant la session asiatique sur le graphique journalier (D1). Il place des ordres en attente (Buy Stop / Sell Stop) de part et d'autre de cette fourchette, avec une marge de sécurité configurable (`MarginPips`). Le trade est déclenché uniquement si le prix perce ce niveau avec une force suffisante, validée par plusieurs filtres.

**Logique de base :**
- **Ordre Achat (BUY)** : Se déclenche si le prix dépasse le `High` de la fourchette asiatique + marge.
- **Ordre Vente (SELL)** : Se déclenche si le prix passe sous le `Low` de la fourchette asiatique - marge.
- **Stop Loss (SL)** : Placé à l'opposé de la fourchette (moins la marge pour un BUY, plus la marge pour un SELL).
- **Take Profit (TP)** : Calculé dynamiquement soit par un ratio risque/rendement fixe, soit par un multiple de l'ATR.

## Prérequis
- **Plateforme** : MetaTrader 5 (Build 2000 ou supérieur recommandé).
- **Compte** : Compte de trading avec accès au Forex (CFD sur devises). Un compte avec exécution rapide est conseillé.
- **Broker** : Doit fournir les données historiques pour les périodes D1 et H1.
- **Connaissances** : Une compréhension du trading sur le Forex et des risques associés est nécessaire.

## Installation
1.  **Télécharger les fichiers** : Récupérez les fichiers `MonEA9.ex5` (le fichier compilé) et `MonEA9.mq5` (le code source, si fourni).
2.  **Ouvrir MetaTrader 5**.
3.  **Ouvrir le dossier de données** :
    *   Cliquez sur `Fichier` dans le menu principal.
    *   Sélectionnez `Ouvrir le dossier de données`.
4.  **Copier l'EA** :
    *   Naviguez jusqu'au sous-dossier `MQL5/Experts/`.
    *   Copiez-y les fichiers `MonEA9.ex5` et `MonEA9.mq5`.
5.  **Redémarrer MT5** : Fermez et rouvrez MetaTrader 5 pour que l'EA soit reconnu.
6.  **Attacher l'EA** :
    *   Dans l'`Navigateur` (Ctrl+N), allez dans `Expert Advisors`.
    *   Faites glisser `MonEA9` sur le graphique de la paire de devises souhaitée (ex: EURUSD).
    *   Une fenêtre de paramètres s'ouvre. Configurez-les selon votre stratégie (voir section suivante).
    *   Cochez `Autoriser le trading automatique` et validez.

## Paramètres Configurables

### 1. Paramètres Généraux
*   `MagicNumber` : Identifiant unique pour les trades de cet EA. Permet de les distinguer des autres.
*   `MaxOpenTrades` : Nombre maximum de positions ouvertes simultanément par l'EA (tous symboles confondus).
*   `MaxTradesPerDay` : Limite du nombre de trades ouverts en une journée.
*   `MinTimeBetweenTrades` : Délai minimum (en heures) à attendre entre deux trades.

### 2. Calcul du Lot
*   `LotMethod` : Méthode de calcul du volume.
    *   `0` : Pourcentage du capital (basé sur l'Equity et le risque par trade).
    *   `1` : Lot fixe.
*   `RiskPercent` : Pourcentage du capital à risquer par trade (si `LotMethod=0`).
*   `FixedLot` : Volume fixe à utiliser (si `LotMethod=1`).
*   `MinLot` / `MaxLot` : Bornes minimales et maximales pour le volume calculé.

### 3. Entrée et Sortie
*   `MarginPips` : Marge en pips ajoutée/soustraite au range asiatique pour définir les niveaux d'entrée et de SL.
*   `TP_Method` : Méthode de calcul du Take Profit.
    *   `0` : Ratio Risque/Rendement fixe.
    *   `1` : Multiple de l'ATR.
*   `Fixed_RR` : Ratio Risque/Rendement fixe (ex: 1.5 pour un R:R de 1:1.5). Utilisé si `TP_Method=0`.
*   `ATR_TP_Mult` : Multiplicateur de la valeur de l'ATR pour le TP. Utilisé si `TP_Method=1`.
*   `UseTrailingStop` : Active/désactive le trailing stop.
*   `Trail_Method` : Méthode de trailing.
    *   `0` : Basé sur un multiple de l'ATR.
    *   `1` : Fixe en pips.
*   `Trail_Mult` / `TrailingStopPips` : Valeur du trailing (selon la méthode).
*   `Trail_Activation_PC` : Pourcentage de profit minimum requis pour activer le trailing stop.

### 4. Filtres de Trading
*   `TradeMonday` ... `TradeFriday` : Jours de la semaine où le trading est autorisé.
*   `TradeStartHour` / `TradeEndHour` : Heures de début et de fin de la session de trading (GMT).
*   `UseNewsFilter` : Active le filtre d'actualités à fort impact.
*   `CloseOnHighImpact` : Ferme automatiquement les positions avant une news à fort impact.
*   `UseBBFilter` : Filtre la largeur du range asiatique via les Bandes de Bollinger.
*   `MinRangePips` / `MaxRangePips` : Largeur minimale et maximale autorisée pour le range (en pips).
*   `UseATRFilter` : Filtre la volatilité générale du marché via l'ATR.
*   `ATR_TF` / `ATRPeriod` : Période et timeframe pour le calcul de l'ATR.
*   `MinATRPips` / `MaxATRPips` : Bornes de l'ATR (en pips) pour autoriser un trade.
*   `ATR_Mult_Min` / `ATR_Mult_Max` : Bornes pour valider la force du breakout (multiple de l'ATR).
*   `UseEMAFilter` : Filtre la tendance via une EMA.
*   `Trend_Filter` : Type de filtre de tendance (`0`=Désactivé, `1`=Strict).
*   `EMATf` / `EMAPeriod` : Timeframe et période de la EMA de tendance.
*   `UseADXFilter` : Filtre la force de la tendance via l'ADX.
*   `ADXPeriod` / `ADXThreshold` : Période et seuil minimum de l'ADX.
*   `UseRSIFilter` : Utilise le RSI pour éviter les zones de surachat/survente.
*   `RSIPeriod` / `RSIOverbought` / `RSIOversold` : Paramètres du RSI.
*   `UseVolumeFilter` : Filtre les signaux par le volume.
*   `VolumePeriod` / `VolumeMultiplier` : Période et multiplicateur pour la moyenne de volume.

### 5. Gestion des Risques & Fermeture
*   `MaxDailyDDPercent` : Drawdown quotidien maximum (en % de l'Equity) avant blocage des nouveaux trades.
*   `MaxTotalDDPercent` : Drawdown total maximum (en % du solde initial) avant arrêt complet de l'EA.
*   `WeekendClose` : Active la fermeture automatique des positions avant le weekend.
*   `FridayCloseHour` : Heure GMT de fermeture des positions le vendredi (si `WeekendClose` activé).

## Utilisation
1.  **Timeframe conseillé** : L'EA est conçu pour fonctionner sur le **graphique H1**. C'est le timeframe principal pour les calculs de tendance (EMA, ADX). Il utilise aussi les données D1 pour le range.
2.  **Symboles** : Paires de devises majeures avec une volatilité adéquate pendant la session asiatique (ex: EURUSD, GBPUSD, USDJPY).
3.  **Lancement** : Après l'avoir attaché au graphique H1, assurez-vous que :
    *   Le trading algorithmique est autorisé dans les paramètres de MT5.
    *   La connexion au serveur de trading est active.
    *   L'icône en haut à droite du graphique affiche un smiley 🙂.
4.  **Monitoring** : Surveillez les logs dans l'onglet `Experts` du `Terminal` pour les messages d'erreur, les confirmations d'ordre et les alertes de drawdown.

## Avertissement sur les Risques
**LE TRADING SUR LE FOREX ET LES CFD IMPLIQUE DES RISQUES ÉLEVÉS DE PERTE FINANCIÈRE.** MonEA9 est un outil automatisé qui exécute une stratégie prédéfinie. Aucun système de trading n'est infaillible.

*   **Tests Rigoureux** : Il est **impératif** de tester l'EA en compte démo pendant une période significative et dans différentes conditions de marché avant de l'utiliser en compte réel.
*   **Capital à Risquer** : N'engagez que du capital dont vous pouvez vous permettre de perdre la totalité.
*   **Compréhension** : Assurez-vous de comprendre tous les paramètres et la logique de la stratégie avant de l'utiliser.
*   **Responsabilité** : Le développeur de l'EA décline toute responsabilité concernant les pertes financières encourues lors de son utilisation. L'utilisateur reste seul responsable de ses décisions de trading et de la configuration de l'EA.
*   **Aucune Garantie** : Les performances passées ne préjugent en aucun cas des résultats futurs.

**Utilisez cet EA à vos propres risques.**
```