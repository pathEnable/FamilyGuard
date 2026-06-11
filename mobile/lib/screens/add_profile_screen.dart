import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

/// Premium multi-step profile creation screen with avatar picker, age slider, PIN setup.
class AddProfileScreen extends StatefulWidget {
  const AddProfileScreen({super.key});

  @override
  AddProfileScreenState createState() => AddProfileScreenState();
}

class AddProfileScreenState extends State<AddProfileScreen>
    with TickerProviderStateMixin {
  // ── State ────────────────────────────────────────────────────────────────
  int _step = 0; // 0 = name/avatar, 1 = age, 2 = PIN
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  int _selectedAge = 10;
  int _selectedColorIndex = 0;
  String _errorMessage = '';
  bool _isLoading = false;
  bool _setPinNow = false;
  bool _obscurePin = true;
  bool _obscureConfirm = true;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  // ── Avatar colors (gradient pairs) ────────────────────────────────────────
  static const List<List<Color>> _avatarColors = [
    [Color(0xFF3B82F6), Color(0xFF1D4ED8)], // Blue
    [Color(0xFF10B981), Color(0xFF047857)], // Green
    [Color(0xFFF59E0B), Color(0xFFB45309)], // Amber
    [Color(0xFFEC4899), Color(0xFFBE185D)], // Pink
    [Color(0xFF8B5CF6), Color(0xFF6D28D9)], // Purple
    [Color(0xFFEF4444), Color(0xFFB91C1C)], // Red
  ];

  static const List<String> _colorNames = [
    'Bleu', 'Vert', 'Orange', 'Rose', 'Violet', 'Rouge',
  ];

  // ── Emoji avatars by age range ─────────────────────────────────────────────
  String get _ageEmoji {
    if (_selectedAge <= 5) return '🐣';
    if (_selectedAge <= 8) return '🌟';
    if (_selectedAge <= 12) return '🎮';
    if (_selectedAge <= 15) return '🎧';
    return '🎓';
  }

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _slideController.forward();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    _bounceController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _bounceController.dispose();
    _nameController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _nextStep() {
    setState(() => _errorMessage = '');

    if (_step == 0) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        setState(() => _errorMessage = 'Le prénom est requis.');
        return;
      }
      if (name.length < 2) {
        setState(() => _errorMessage = 'Le prénom doit avoir au moins 2 caractères.');
        return;
      }
    }

    if (_step < 2) {
      setState(() => _step++);
      _slideController.reset();
      _bounceController.reset();
      _slideController.forward();
      _bounceController.forward();
    } else {
      _createProfile();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() {
        _step--;
        _errorMessage = '';
      });
      _slideController.reset();
      _slideController.forward();
    } else {
      Navigator.pop(context, false);
    }
  }

  // ── API Call ────────────────────────────────────────────────────────────────
  Future<void> _createProfile() async {
    // Validate PIN if user wants one
    if (_setPinNow) {
      final pin = _pinController.text.trim();
      final confirm = _confirmPinController.text.trim();
      if (pin.length < 4) {
        setState(() => _errorMessage = 'Le PIN doit contenir au moins 4 chiffres.');
        return;
      }
      if (pin != confirm) {
        setState(() => _errorMessage = 'Les PINs ne correspondent pas.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final profile = await ApiService.createProfile(
        name: _nameController.text.trim(),
        age: _selectedAge,
      );

      // Set PIN if requested
      if (_setPinNow && _pinController.text.trim().isNotEmpty) {
        await ApiService.setPin(profile['id'], _pinController.text.trim());
        // Sync PIN to native Android for offline lock screen verification
        try {
          const pinChannel = MethodChannel('com.familyguard/pin');
          await pinChannel.invokeMethod('setPin', {'pin': _pinController.text.trim()});
        } catch (_) {
          // Non-critical: PIN will still work online
        }
      }

      if (!mounted) return;
      
      // Show success animation then pop
      _showSuccessAndPop();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showSuccessAndPop() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, val, child) => Transform.scale(scale: val, child: child),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _avatarColors[_selectedColorIndex],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Profil créé !',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${_nameController.text.trim()} est prêt à être protégé 🛡️',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(true);
                },
                child: const Text('Continuer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final primaryColor = _avatarColors[_selectedColorIndex][0];
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _prevStep,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Spacer(),
                  // Step indicators
                  Row(
                    children: List.generate(3, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _step == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= _step ? primaryColor : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // balance
                ],
              ),
            ),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _buildStep(primaryColor, theme),
                ),
              ),
            ),

            // ── Error message ─────────────────────────────────────────────
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Next / Submit button ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _nextStep,
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _step == 2 ? 'Créer le profil' : 'Continuer',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Icon(_step == 2 ? Icons.check_circle_outline : Icons.arrow_forward_rounded),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(Color primaryColor, ThemeData theme) {
    switch (_step) {
      case 0:
        return _buildStep0(primaryColor, theme);
      case 1:
        return _buildStep1(primaryColor, theme);
      case 2:
        return _buildStep2(primaryColor, theme);
      default:
        return const SizedBox();
    }
  }

  // ─── Step 0: Name + Avatar color ──────────────────────────────────────────
  Widget _buildStep0(Color primaryColor, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // Big animated avatar
        Center(
          child: ScaleTransition(
            scale: _bounceAnim,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _avatarColors[_selectedColorIndex],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _nameController.text.isEmpty
                          ? '👶'
                          : _nameController.text.trim()[0].toUpperCase(),
                      style: const TextStyle(fontSize: 52, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: const Icon(Icons.palette_outlined, size: 18, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text('Étape 1 sur 3', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        const Text(
          'Qui protéger ?',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Donnez un prénom à ce profil et choisissez sa couleur.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
        ),
        const SizedBox(height: 32),

        // Name input
        _buildLabel('Prénom de l\'enfant'),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Ex : Lucas',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Color picker
        _buildLabel('Couleur du profil'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(_avatarColors.length, (i) {
            final isSelected = _selectedColorIndex == i;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedColorIndex = i);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _avatarColors[i],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: _avatarColors[i][0].withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)]
                      : [],
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          _colorNames[_selectedColorIndex],
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ─── Step 1: Age slider ────────────────────────────────────────────────────
  Widget _buildStep1(Color primaryColor, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // Big emoji based on age
        Center(
          child: ScaleTransition(
            scale: _bounceAnim,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _avatarColors[_selectedColorIndex],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(_ageEmoji, style: const TextStyle(fontSize: 52)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        Text('Étape 2 sur 3', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        const Text(
          'Quel âge a-t-il ?',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        const Text(
          'L\'âge détermine les recommandations de temps d\'écran.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
        ),
        const SizedBox(height: 40),

        // Big age display
        Center(
          child: Column(
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  height: 1,
                ),
                child: Text('$_selectedAge'),
              ),
              const Text('ans', style: TextStyle(fontSize: 22, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: primaryColor,
            inactiveTrackColor: const Color(0xFFE2E8F0),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            overlayColor: primaryColor.withValues(alpha: 0.15),
            trackHeight: 8,
          ),
          child: Slider(
            value: _selectedAge.toDouble(),
            min: 2,
            max: 18,
            divisions: 16,
            onChanged: (val) {
              setState(() => _selectedAge = val.round());
              HapticFeedback.selectionClick();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('2 ans', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              Text('18 ans', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Age-based recommendation card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: primaryColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommandation OMS',
                      style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getAgeRecommendation(),
                      style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getAgeRecommendation() {
    if (_selectedAge <= 5) return 'Maximum 1h par jour, avec accompagnement parental.';
    if (_selectedAge <= 10) return '1h à 2h par jour recommandées. Favoriser les pauses.';
    if (_selectedAge <= 13) return '2h max hors temps scolaire. Éviter avant le coucher.';
    return 'Accompagner l\'usage plutôt que de l\'interdire. Dialogue recommandé.';
  }

  // ─── Step 2: PIN (optional) ────────────────────────────────────────────────
  Widget _buildStep2(Color primaryColor, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Center(
          child: ScaleTransition(
            scale: _bounceAnim,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _avatarColors[_selectedColorIndex],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.lock_rounded, color: Colors.white, size: 52),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        Text('Étape 3 sur 3', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        const Text(
          'Sécuriser le profil',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Un code PIN empêchera votre enfant de quitter l\'interface de protection.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
        ),
        const SizedBox(height: 32),

        // Toggle
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SwitchListTile(
            value: _setPinNow,
            onChanged: (val) => setState(() => _setPinNow = val),
            activeTrackColor: primaryColor.withValues(alpha: 0.5),
            activeThumbColor: primaryColor,
            title: const Text('Définir un code PIN maintenant', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Vous pourrez aussi le définir plus tard', style: TextStyle(fontSize: 13)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _setPinNow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildLabel('Code PIN (4 à 6 chiffres)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pinController,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '• • • •',
                        hintStyle: const TextStyle(letterSpacing: 8),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscurePin = !_obscurePin),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Confirmer le code PIN'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _confirmPinController,
                      obscureText: _obscureConfirm,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '• • • •',
                        hintStyle: const TextStyle(letterSpacing: 8),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox(),
        ),

        if (!_setPinNow) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Sans PIN, l\'enfant peut fermer l\'interface de protection. Vous pourrez en définir un plus tard.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF374151)),
    );
  }
}
