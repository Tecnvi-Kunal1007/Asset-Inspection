import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BillboardFooter extends StatefulWidget {
  const BillboardFooter({Key? key}) : super(key: key);

  @override
  State<BillboardFooter> createState() => _BillboardFooterState();
}

class _BillboardFooterState extends State<BillboardFooter>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0, // Start from the beginning
      end: 1.0, // End at the end of one complete cycle
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    // Start the animation and repeat it
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30, // Fixed height as requested
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.blue.shade800,
            Colors.blue.shade600,
            Colors.blue.shade800,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                -_animation.value *
                    800, // Adjust this value based on content width
                0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // First set of items
                  _buildFooterItem(Icons.info, 'Created and maintained by '),
                  _buildFooterItem(Icons.business, 'Tecnvirons Pvt Ltd'),
                  _buildFooterItem(Icons.email, 'ai@tecnvi-ai.com'),
                  _buildFooterItem(Icons.phone, '8828825499'),

                  // Second set for continuous loop
                  _buildFooterItem(Icons.info, 'Created and maintained by '),
                  _buildFooterItem(Icons.business, 'Tecnvirons Pvt Ltd'),
                  _buildFooterItem(Icons.email, 'ai@tecnvi-ai.com'),
                  _buildFooterItem(Icons.phone, '8828825499'),

                  // Third set to ensure smooth transition
                  _buildFooterItem(Icons.info, 'Created and maintained by '),
                  _buildFooterItem(Icons.business, 'Tecnvirons Pvt Ltd'),
                  _buildFooterItem(Icons.email, 'ai@tecnvi-ai.com'),
                  _buildFooterItem(Icons.phone, '8828825499'),

                  // Fourth set for extra smoothness
                  _buildFooterItem(Icons.info, 'Created and maintained by '),
                  _buildFooterItem(Icons.business, 'Tecnvirons Pvt Ltd'),
                  _buildFooterItem(Icons.email, 'ai@tecnvi-ai.com'),
                  _buildFooterItem(Icons.phone, '8828825499'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooterItem(IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 11),
          const SizedBox(width: 3),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
