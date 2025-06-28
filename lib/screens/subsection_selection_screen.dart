// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import '../models/premise.dart';
// import '../models/section.dart';
// import '../models/subsection.dart';
// import '../utils/responsive_helper.dart';
// import '../utils/theme_helper.dart';
// import '../services/supabase_service.dart';
// import 'create_subsection_product_screen.dart';
// import 'CreateSubsectionScreen.dart';
//
// class SubsectionSelectionScreen extends StatelessWidget {
//   final Premise premise;
//   final Section section;
//   final List<Subsection> subsections;
//
//   const SubsectionSelectionScreen({
//     super.key,
//     required this.premise,
//     required this.section,
//     required this.subsections,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: Colors.purple,
//         title: Text(
//           'Select Subsection for Product',
//           style: GoogleFonts.poppins(
//             fontSize: ResponsiveHelper.getFontSize(context, 20),
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//           ),
//         ),
//         flexibleSpace: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Colors.purple, Colors.purple.shade700],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//       ),
//       body: subsections.isEmpty
//           ? Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.room_outlined,
//               size: ResponsiveHelper.getIconSize(context, 64),
//               color: Colors.grey.shade400,
//             ),
//             SizedBox(height: ResponsiveHelper.getSpacing(context, 24)),
//             Text(
//               'No Subsections Available',
//               style: GoogleFonts.poppins(
//                 fontSize: ResponsiveHelper.getFontSize(context, 20),
//                 fontWeight: FontWeight.w600,
//                 color: ThemeHelper.textPrimary,
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.getSpacing(context, 8)),
//             Text(
//               'Create a subsection first to proceed.',
//               style: GoogleFonts.poppins(
//                 fontSize: ResponsiveHelper.getFontSize(context, 14),
//                 color: ThemeHelper.textSecondary,
//               ),
//             ),
//             SizedBox(height: ResponsiveHelper.getSpacing(context, 16)),
//             ElevatedButton(
//               onPressed: () => Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => CreateSubsectionScreen(
//                     premise: premise,
//                     sectionId: section.id,
//                   ),
//                 ),
//               ),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.orange,
//                 padding: EdgeInsets.symmetric(
//                   horizontal: ResponsiveHelper.getUniformPadding(context),
//                   vertical: ResponsiveHelper.getUniformPadding(context) / 1.5,
//                 ),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               child: Text(
//                 'Create Subsection',
//                 style: GoogleFonts.poppins(
//                   fontSize: ResponsiveHelper.getFontSize(context, 16),
//                   fontWeight: FontWeight.w600,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       )
//           : ListView.builder(
//         padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
//         itemCount: subsections.length,
//         itemBuilder: (context, index) {
//           final subsection = subsections[index];
//           return Card(
//             elevation: 2,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             child: InkWell(
//               borderRadius: BorderRadius.circular(12),
//               onTap: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => SubsectionProductsScreen(
//                       premise: premise,
//                       subsectionId: subsection.id, subsectionName: '',
//                     ),
//                   ),
//                 );
//               },
//               child: Padding(
//                 padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
//                 child: Row(
//                   children: [
//                     Container(
//                       padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) / 1.5),
//                       decoration: BoxDecoration(
//                         color: Colors.orange.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Icon(
//                         Icons.room,
//                         color: Colors.orange,
//                         size: ResponsiveHelper.getIconSize(context, 24),
//                       ),
//                     ),
//                     SizedBox(width: ResponsiveHelper.getSpacing(context, 16)),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             subsection.name,
//                             style: GoogleFonts.poppins(
//                               fontSize: ResponsiveHelper.getFontSize(context, 16),
//                               fontWeight: FontWeight.w600,
//                               color: ThemeHelper.textPrimary,
//                             ),
//                           ),
//                           Text(
//                             'In ${section.name}',
//                             style: GoogleFonts.poppins(
//                               fontSize: ResponsiveHelper.getFontSize(context, 14),
//                               color: ThemeHelper.textSecondary,
//                             ),
//                           ),
//                           if (subsection.additionalData?['location'] != null)
//                             Row(
//                               children: [
//                                 Icon(
//                                   Icons.location_on,
//                                   size: ResponsiveHelper.getIconSize(context, 14),
//                                   color: Colors.grey.shade600,
//                                 ),
//                                 SizedBox(width: ResponsiveHelper.getSpacing(context, 4)),
//                                 Text(
//                                   subsection.additionalData!['location'].toString(),
//                                   style: GoogleFonts.poppins(
//                                     fontSize: ResponsiveHelper.getFontSize(context, 12),
//                                     color: Colors.grey.shade600,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                         ],
//                       ),
//                     ),
//                     Icon(
//                       Icons.arrow_forward_ios,
//                       size: ResponsiveHelper.getIconSize(context, 16),
//                       color: Colors.grey.shade400,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }