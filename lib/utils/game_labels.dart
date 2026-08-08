import '../l10n/app_localizations.dart';
import '../models/around_the_clock_game.dart';
import '../models/cricket_game.dart';
import '../models/game.dart';
import '../models/shanghai_game.dart';

/// Localized display names for the per-mode game settings, shared by the
/// history lists, the history detail screens and the rematch dialog so the
/// same setting always reads the same way.

/// Localized display name for an X01 check-in [mode].
String checkInLabel(AppLocalizations l, GameMode mode) {
  switch (mode) {
    case GameMode.straightIn:
      return l.straight;
    case GameMode.doubleIn:
      return l.double_;
    case GameMode.masterIn:
      return l.master;
  }
}

/// Localized display name for an X01 check-out [mode].
String checkOutLabel(AppLocalizations l, CheckoutMode mode) {
  switch (mode) {
    case CheckoutMode.straightOut:
      return l.straight;
    case CheckoutMode.doubleOut:
      return l.double_;
    case CheckoutMode.masterOut:
      return l.master;
  }
}

/// Localized display name for a Cricket [variant].
String cricketVariantLabel(AppLocalizations l, CricketVariant variant) {
  switch (variant) {
    case CricketVariant.normal:
      return l.cricketVariantNormal;
    case CricketVariant.cutThroat:
      return l.cricketVariantCutThroat;
  }
}

/// Localized display name for a Cricket scoring [mode].
String cricketScoringModeLabel(AppLocalizations l, CricketScoringMode mode) {
  switch (mode) {
    case CricketScoringMode.standard:
      return l.cricketStandard;
    case CricketScoringMode.simple:
      return l.cricketSimple;
  }
}

/// Localized display name for a Shanghai [variant].
String shanghaiVariantLabel(AppLocalizations l, ShanghaiVariant variant) {
  switch (variant) {
    case ShanghaiVariant.classic:
      return l.shanghaiClassic;
    case ShanghaiVariant.clockwise:
      return l.shanghaiClockwise;
    case ShanghaiVariant.sequential:
      return l.shanghaiSequential;
  }
}

/// Localized display name for an Around the Clock [variant].
String aroundTheClockVariantLabel(
    AppLocalizations l, AroundTheClockVariant variant) {
  switch (variant) {
    case AroundTheClockVariant.basic:
      return l.aroundClockBasic;
    case AroundTheClockVariant.fullSegments:
      return l.aroundClockFullSegments;
    case AroundTheClockVariant.skipRules:
      return l.aroundClockSkipRules;
  }
}
