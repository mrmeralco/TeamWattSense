/// A conservative, offline gate; the model also receives a scope instruction.
String? miraLocalReply(String question,
    {bool hasHistory = false, String language = 'en'}) {
  final q = question.trim().toLowerCase();
  if (q.length > 600) {
    return 'Please keep your WattWise question under 600 characters.';
  }
  final injection = RegExp(
      r'ignore.{0,30}(instruction|prompt|rule)|system prompt|developer message|jailbreak|pretend to be|act as|forget.{0,20}(rule|instruction)',
      caseSensitive: false);
  final topic = RegExp(
      r'\b(wattwise|mira|electricity|electrical|energy|appliance|appliances|bills|meralco|kwh|watt|watts|wattage|bill|billing|tariff|consumption|aircon|airconditioner|ac|tv|fans|lamp|computer|laptop|rice cooker|washing machine|oven|refrigerator|fridge|fan|heater|washer|dryer|television|microwave|solar|standby|kuryente|konsumo|saksakan|bayarin|singil|matipid|makatipid|ilaw)\b',
      caseSensitive: false);
  final followup = RegExp(
      r'^(why|how|explain more|tell me more|what should i change|bakit|paano|yes|oo)[?.! ]*$');
  final unrelated = RegExp(
      r'\b(recipe|poem|essay|politics|election|celebrity|horoscope|sports|dating|homework|python|javascript|roleplay)\b');
  if (injection.hasMatch(q) ||
      unrelated.hasMatch(q) ||
      (!topic.hasMatch(q) && !(hasHistory && followup.hasMatch(q)))) {
    return language == 'fil'
        ? 'Tungkol lang sa WattWise, appliances, konsumo ng kuryente at electricity bill ang masasagot ko.'
        : 'I can only help with WattWise, appliance electricity usage, energy savings and electricity bills.';
  }
  return null;
}
