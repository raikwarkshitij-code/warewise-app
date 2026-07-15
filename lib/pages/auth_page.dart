import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/brand_logo.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // Tokenized Emerald Green Design System Colors
  static const Color emeraldDarkForest = Color(0xFF01604B);
  static const Color emeraldCore = Color(0xFF009473);
  static const Color emeraldSage = Color(0xFF6BC1AE);
  static const Color emeraldPastel = Color(0xFF99D4C7);

  bool isLogin = true;
  bool isGerman = false; // Controls localization strings globally across layout

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? errorMessage;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      setState(() => errorMessage = isGerman
          ? 'Bitte füllen Sie alle Anmeldefelder aus.'
          : 'Please fill out all credential fields.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message);
    } catch (e) {
      setState(() => errorMessage = e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- TOP MANDATORY BRAND LOGO ASSET ---
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: emeraldCore,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const BrandLogo(size: 48),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: Text(
                      'WareWise',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: emeraldDarkForest,
                              ),
                    ),
                  ),
                  Center(
                    child: Text(
                      isGerman
                          ? 'Intelligente Bestandsverwaltung'
                          : 'Smarter Inventory, Simpler Operations',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- MULTILINGUAL TOGGLE RAIL ---
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isGerman ? '🇩🇪 Deutsch' : '🇬🇧 English',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: emeraldDarkForest),
                        ),
                        Switch(
                          value: isGerman,
                          activeColor: emeraldCore,
                          inactiveTrackColor: emeraldPastel,
                          onChanged: (value) {
                            setState(() {
                              isGerman = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- MAIN USER ACTION CARD FORM CONTAINER ---
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black12,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGerman ? 'Willkommen zurück' : 'Welcome Back',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: emeraldDarkForest,
                            ),
                          ),
                          Text(
                            isGerman
                                ? 'Anmelden, um das Lager zu verwalten'
                                : 'Sign in to manage your warehouse',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 24),

                          // Email Input field
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: isGerman ? 'E-Mail' : 'Email',
                              labelStyle: const TextStyle(
                                  color: Colors.black54, fontSize: 14),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: emeraldPastel),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: emeraldCore, width: 2),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password Input field
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => submit(),
                            decoration: InputDecoration(
                              labelText: isGerman ? 'Passwort' : 'Password',
                              labelStyle: const TextStyle(
                                  color: Colors.black54, fontSize: 14),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: emeraldPastel),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: emeraldCore, width: 2),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),

                          if (errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Execution Button (Emerald Green Accent)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: emeraldCore,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: isLoading ? null : submit,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      isLogin
                                          ? (isGerman ? 'Einloggen' : 'Sign In')
                                          : (isGerman
                                              ? 'Registrieren'
                                              : 'Register'),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- SUB VIEW DISPATCH INTERCHANGE LINK (ACCOUNT TOGGLE) ---
                  Center(
                    child: TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: emeraldDarkForest),
                      onPressed: () {
                        setState(() {
                          isLogin = !isLogin;
                          errorMessage = null;
                        });
                      },
                      child: Text(
                        isLogin
                            ? (isGerman
                                ? "Noch kein Konto? Registrieren"
                                : "Don't have an account? Register")
                            : (isGerman
                                ? "Bereits registriert? Einloggen"
                                : "Already have an account? Sign In"),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
