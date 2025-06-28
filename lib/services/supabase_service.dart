
import 'dart:typed_data';
import 'dart:ui';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/premise.dart';
import '../models/premise_product.dart';
import '../models/section_product.dart';
import '../models/subsection_product.dart';
import '../models/section.dart';
import '../models/site.dart';
import '../models/floor.dart';
import '../models/hydrant_valve.dart';
import '../models/hydrant_ug.dart';
import '../models/hydrant_wheel.dart';
import '../models/hydrant_cap.dart';
import '../models/hydrant_mouth_gasket.dart';
import '../models/canvas_hose.dart';
import '../models/branch_pipe.dart';
import '../models/fireman_axe.dart';
import '../models/hose_reel.dart';
import '../models/shut_off_nozzle.dart';
import '../models/key_glass.dart';
import '../models/pressure_gauge.dart';
import '../models/abc_extinguisher.dart';
import '../models/sprinkler_zcv.dart';
import '../models/smoke_detector.dart';
import '../models/heat_detector.dart';
import '../models/flasher_hooter_alarm.dart';
import '../models/control_module.dart';
import '../models/flow_switch.dart';
import '../models/monitor_module.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/subsection.dart';
import '../models/telephone_jack.dart';
import '../models/speaker.dart';
import '../models/building_accessories.dart';
import '../models/area.dart';


class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();
  
  // Product Operations by Subsection
  Future<List<Product>> getProductsBySubsectionId(String subsectionId) async {
    final response = await _supabase
        .from('subsection_products')
        .select()
        .eq('subsection_id', subsectionId);
    
    return response.map((json) => Product.fromJson(json)).toList();
  }

  // Site Operations
  Future<Site> createSite(Site site) async {
    final response =
        await _supabase.from('sites').insert(site.toJson()).select().single();
    return Site.fromJson(response);
  }

  Future<List<Site>> getSites() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Get the contractor record for the current user
    final contractorData =
        await _supabase
            .from('contractor')
            .select()
            .eq('id', user.id)
            .maybeSingle();

    if (contractorData == null) {
      // If not a contractor, return empty list
      return [];
    }

    // Get sites for this contractor
    final response = await _supabase
        .from('sites')
        .select()
        .eq('contractor_id', user.id);

    return (response as List).map((json) => Site.fromJson(json)).toList();
  }

  Future<Site> getSiteById(String id) async {
    final response =
        await _supabase.from('sites').select().eq('id', id).single();
    return Site.fromJson(response);
  }

  Future<Map<String, dynamic>> getSiteDetails(String siteId) async {
    final response =
        await _supabase.from('sites').select().eq('id', siteId).single();
    return response;
  }

  Future<void> updateSite(String siteId, Map<String, dynamic> siteData) async {
    await _supabase.from('sites').update(siteData).eq('id', siteId);
  }

  Future<void> deleteSite(String siteId) async {
    await _supabase.from('sites').delete().eq('id', siteId);
  }

  // Area Operations
  Future<Area> createArea(Area area) async {
    final response =
        await _supabase.from('areas').insert(area.toJson()).select().single();
    return Area.fromJson(response);
  }

  Future<List<Area>> getAreas() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final response = await _supabase
        .from('areas')
        .select()
        .eq('contractor_id', user.id);

    return (response as List).map((json) => Area.fromJson(json)).toList();
  }

  Future<Area> getAreaById(String id) async {
    final response =
        await _supabase.from('areas').select().eq('id', id).single();
    return Area.fromJson(response);
  }

  Future<void> updateArea(Area area) async {
    await _supabase.from('areas').update(area.toJson()).eq('id', area.id);
  }

  Future<void> deleteArea(String areaId) async {
    await _supabase.from('areas').delete().eq('id', areaId);
  }

  // Modified Site Operations to include area
  Future<List<Site>> getSitesByArea(String areaId) async {
    final response = await _supabase
        .from('sites')
        .select()
        .eq('area_id', areaId);

    return (response as List).map((json) => Site.fromJson(json)).toList();
  }



  // QR Code Storage
  Future<String> uploadQrCode(String pumpId, File qrCodeFile) async {
    final fileExt = qrCodeFile.path.split('.').last;
    final fileName = '$pumpId.$fileExt';

    await _supabase.storage.from('qr_codes').upload(fileName, qrCodeFile);

    return _supabase.storage.from('qr_codes').getPublicUrl(fileName);
  }

  Future<String> uploadSocietyReport(
    String siteId,
    File reportFile, {
    String? reportName,
  }) async {
    final fileExt = reportFile.path.split('.').last;
    final fileName =
        '$siteId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    await _supabase.storage.from('societyreports').upload(fileName, reportFile);
    final publicUrl = _supabase.storage
        .from('societyreports')
        .getPublicUrl(fileName);

    await _supabase.from('site_reports').insert({
      'site_id': siteId,
      'file_name': reportName ?? fileName,
      'url': publicUrl,
      'uploaded_at': DateTime.now().toIso8601String(),
    });

    return publicUrl;
  }

  // Add this new method to get all reports for a site
  Future<List<Map<String, dynamic>>> getSiteReports(String siteId) async {
    final response = await _supabase
        .from('site_reports')
        .select()
        .eq('site_id', siteId)
        .order('uploaded_at', ascending: false);

    return response;
  }

  // Floor related methods
  Future<List<Floor>> getFloorsBySiteId(String siteId) async {
    try {
      final response = await _supabase
          .from('floors')
          .select()
          .eq('site_id', siteId)
          .order('created_at', ascending: true);

      return (response as List).map((json) => Floor.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error fetching floors: $e');
    }
  }

  Future<Floor> createFloor(
    String siteId,
    String floorType, {
    String? remarks,
  }) async {
    try {
      final response =
          await _supabase.from('floors').insert({
            'site_id': siteId,
            'floor_type': floorType,
            'remarks': remarks,
          }).select();

      // Handle response as list and take first element
      if (response is List && response.isNotEmpty) {
        return Floor.fromJson(response.first);
      } else {
        throw Exception('No floor data returned from insert');
      }
    } catch (e) {
      throw Exception('Error creating floor: $e');
    }
  }

  Future<void> deleteFloor(String floorId) async {
    try {
      await _supabase.from('floors').delete().eq('id', floorId);
    } catch (e) {
      throw Exception('Error deleting floor: $e');
    }
  }

  Future<Floor> updateFloor(
    String floorId,
    String floorType, {
    String? remarks,
  }) async {
    try {
      final response =
          await _supabase
              .from('floors')
              .update({
                'floor_type': floorType,
                'remarks': remarks,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', floorId)
              .select()
              .single();

      return Floor.fromJson(response);
    } catch (e) {
      throw Exception('Error updating floor: $e');
    }
  }

  // Create default floors for a site
  Future<List<Floor>> createDefaultFloors(String siteId, int floorCount) async {
    try {
      // Prepare all floor data for batch insert
      final List<Map<String, dynamic>> floorsData = [];
      for (int i = 1; i <= floorCount; i++) {
        floorsData.add({
          'site_id': siteId,
          'floor_type': 'Floor $i',
          'remarks': null,
        });
      }

      // Batch insert all floors at once
      final response =
          await _supabase.from('floors').insert(floorsData).select();

      // Convert response to Floor objects
      if (response is List) {
        return response.map((json) => Floor.fromJson(json)).toList();
      } else {
        throw Exception('Unexpected response format from batch insert');
      }
    } catch (e) {
      throw Exception('Error creating default floors: $e');
    }
  }

  // Hydrant Valve related methods
  Future<List<HydrantValve>> getHydrantValvesByFloorId(String floorId) async {
    try {
      final response = await _supabase
          .from('hydrant_valves')
          .select()
          .eq('floor_id', floorId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => HydrantValve.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error fetching hydrant valves: $e');
    }
  }

  Future<HydrantValve> getHydrantValveById(String valveId) async {
    try {
      final response =
          await _supabase
              .from('hydrant_valves')
              .select()
              .eq('id', valveId)
              .single();
      return HydrantValve.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching hydrant valve: $e');
    }
  }

  Future<void> createHydrantValve(
    String floorId,
    String valveType,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase.from('hydrant_valves').insert({
        'floor_id': floorId,
        'valve_type': valveType,
        'status': status,
        'note': note,
      });
    } catch (e) {
      throw Exception('Failed to create hydrant valve: $e');
    }
  }

  Future<void> deleteHydrantValve(String valveId) async {
    try {
      await _supabase.from('hydrant_valves').delete().eq('id', valveId);
    } catch (e) {
      throw Exception('Error deleting hydrant valve: $e');
    }
  }

  Future<void> updateHydrantValve(
    String valveId,
    String valveType,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase
          .from('hydrant_valves')
          .update({
            'valve_type': valveType,
            'status': status,
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', valveId);
    } catch (e) {
      throw Exception('Failed to update hydrant valve: $e');
    }
  }

  // Hydrant UG related methods
  Future<List<HydrantUG>> getHydrantUGsByFloorId(String floorId) async {
    try {
      final response = await _supabase
          .from('hydrant_ugs')
          .select()
          .eq('floor_id', floorId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => HydrantUG.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error fetching hydrant UGs: $e');
    }
  }

  Future<HydrantUG> getHydrantUGById(String ugId) async {
    try {
      final response =
          await _supabase.from('hydrant_ugs').select().eq('id', ugId).single();
      return HydrantUG.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching hydrant UG: $e');
    }
  }

  Future<void> createHydrantUG(
    String floorId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase.from('hydrant_ugs').insert({
        'floor_id': floorId,
        'status': status,
        'note': note,
      });
    } catch (e) {
      throw Exception('Error creating hydrant UG: $e');
    }
  }

  Future<void> deleteHydrantUG(String ugId) async {
    try {
      await _supabase.from('hydrant_ugs').delete().eq('id', ugId);
    } catch (e) {
      throw Exception('Error deleting hydrant UG: $e');
    }
  }

  Future<void> updateHydrantUG(
    String ugId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase
          .from('hydrant_ugs')
          .update({
            'status': status,
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', ugId);
    } catch (e) {
      throw Exception('Error updating hydrant UG: $e');
    }
  }

  // Hydrant Wheel related methods
  Future<List<HydrantWheel>> getHydrantWheelsByFloorId(String floorId) async {
    try {
      final response = await _supabase
          .from('hydrant_wheels')
          .select()
          .eq('floor_id', floorId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => HydrantWheel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error fetching hydrant wheels: $e');
    }
  }

  Future<HydrantWheel> getHydrantWheelById(String wheelId) async {
    try {
      final response =
          await _supabase
              .from('hydrant_wheels')
              .select()
              .eq('id', wheelId)
              .single();
      return HydrantWheel.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching hydrant wheel: $e');
    }
  }

  Future<void> createHydrantWheel(
    String floorId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase.from('hydrant_wheels').insert({
        'floor_id': floorId,
        'status': status,
        'note': note,
      });
    } catch (e) {
      throw Exception('Error creating hydrant wheel: $e');
    }
  }

  Future<void> deleteHydrantWheel(String wheelId) async {
    try {
      await _supabase.from('hydrant_wheels').delete().eq('id', wheelId);
    } catch (e) {
      throw Exception('Error deleting hydrant wheel: $e');
    }
  }

  Future<void> updateHydrantWheel(
    String wheelId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase
          .from('hydrant_wheels')
          .update({
            'status': status,
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', wheelId);
    } catch (e) {
      throw Exception('Error updating hydrant wheel: $e');
    }
  }

  // Hydrant Cap related methods
  Future<List<HydrantCap>> getHydrantCapsByFloorId(String floorId) async {
    try {
      final response = await _supabase
          .from('hydrant_caps')
          .select()
          .eq('floor_id', floorId)
          .order('created_at');

      return response.map((json) => HydrantCap.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load hydrant caps: $e');
    }
  }

  Future<HydrantCap> getHydrantCapById(String capId) async {
    try {
      final response =
          await _supabase
              .from('hydrant_caps')
              .select()
              .eq('id', capId)
              .single();
      return HydrantCap.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching hydrant cap: $e');
    }
  }

  Future<void> createHydrantCap(
    String floorId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase.from('hydrant_caps').insert({
        'floor_id': floorId,
        'status': status,
        'note': note,
      });
    } catch (e) {
      throw Exception('Failed to create hydrant cap: $e');
    }
  }

  Future<void> updateHydrantCap(
    String capId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase
          .from('hydrant_caps')
          .update({
            'status': status,
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', capId);
    } catch (e) {
      throw Exception('Failed to update hydrant cap: $e');
    }
  }

  Future<void> deleteHydrantCap(String capId) async {
    try {
      await _supabase.from('hydrant_caps').delete().eq('id', capId);
    } catch (e) {
      throw Exception('Failed to delete hydrant cap: $e');
    }
  }

  // Hydrant Mouth Gasket related methods
  Future<List<HydrantMouthGasket>> getHydrantMouthGasketsByFloorId(
    String floorId,
  ) async {
    try {
      final response = await _supabase
          .from('hydrant_mouth_gaskets')
          .select()
          .eq('floor_id', floorId)
          .order('created_at');

      return response.map((json) => HydrantMouthGasket.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load hydrant mouth gaskets: $e');
    }
  }

  Future<HydrantMouthGasket> getHydrantMouthGasketById(String gasketId) async {
    try {
      final response =
          await _supabase
              .from('hydrant_mouth_gaskets')
              .select()
              .eq('id', gasketId)
              .single();
      return HydrantMouthGasket.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching hydrant mouth gasket: $e');
    }
  }

  Future<void> createHydrantMouthGasket(
    String floorId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase.from('hydrant_mouth_gaskets').insert({
        'floor_id': floorId,
        'status': status,
        'note': note,
      });
    } catch (e) {
      throw Exception('Failed to create hydrant mouth gasket: $e');
    }
  }

  Future<void> updateHydrantMouthGasket(
    String gasketId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase
          .from('hydrant_mouth_gaskets')
          .update({
            'status': status,
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', gasketId);
    } catch (e) {
      throw Exception('Failed to update hydrant mouth gasket: $e');
    }
  }

  Future<void> deleteHydrantMouthGasket(String gasketId) async {
    try {
      await _supabase.from('hydrant_mouth_gaskets').delete().eq('id', gasketId);
    } catch (e) {
      throw Exception('Failed to delete hydrant mouth gasket: $e');
    }
  }

  // Canvas Hose related methods
  Future<List<CanvasHose>> getCanvasHosesByFloorId(String floorId) async {
    try {
      final response = await _supabase
          .from('canvas_hoses')
          .select()
          .eq('floor_id', floorId)
          .order('created_at');

      return response.map((json) => CanvasHose.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load canvas hoses: $e');
    }
  }

  Future<CanvasHose> getCanvasHoseById(String hoseId) async {
    try {
      final response =
          await _supabase
              .from('canvas_hoses')
              .select()
              .eq('id', hoseId)
              .single();
      return CanvasHose.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching canvas hose: $e');
    }
  }

  Future<void> createCanvasHose(
    String floorId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase.from('canvas_hoses').insert({
        'floor_id': floorId,
        'status': status,
        'note': note,
      });
    } catch (e) {
      throw Exception('Failed to create canvas hose: $e');
    }
  }

  Future<void> updateCanvasHose(
    String hoseId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase
          .from('canvas_hoses')
          .update({
            'status': status,
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', hoseId);
    } catch (e) {
      throw Exception('Failed to update canvas hose: $e');
    }
  }

  Future<void> deleteCanvasHose(String hoseId) async {
    try {
      await _supabase.from('canvas_hoses').delete().eq('id', hoseId);
    } catch (e) {
      throw Exception('Failed to delete canvas hose: $e');
    }
  }

  // Branch Pipe related methods
  Future<List<BranchPipe>> getBranchPipesByFloorId(String floorId) async {
    try {
      final response = await _supabase
          .from('branch_pipes')
          .select()
          .eq('floor_id', floorId)
          .order('created_at');

      return response.map((json) => BranchPipe.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load branch pipes: $e');
    }
  }

  Future<BranchPipe> getBranchPipeById(String pipeId) async {
    try {
      final response =
          await _supabase
              .from('branch_pipes')
              .select()
              .eq('id', pipeId)
              .single();
      return BranchPipe.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching branch pipe: $e');
    }
  }

  Future<void> createBranchPipe(
    String floorId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase.from('branch_pipes').insert({
        'floor_id': floorId,
        'status': status,
        'note': note,
      });
    } catch (e) {
      throw Exception('Failed to create branch pipe: $e');
    }
  }

  Future<void> updateBranchPipe(
    String pipeId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase
          .from('branch_pipes')
          .update({
            'status': status,
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pipeId);
    } catch (e) {
      throw Exception('Failed to update branch pipe: $e');
    }
  }

  Future<void> deleteBranchPipe(String pipeId) async {
    try {
      await _supabase.from('branch_pipes').delete().eq('id', pipeId);
    } catch (e) {
      throw Exception('Failed to delete branch pipe: $e');
    }
  }

  // Fireman Axe related methods
  Future<List<FiremanAxe>> getFiremanAxesByFloorId(String floorId) async {
    try {
      final response = await _supabase
          .from('fireman_axes')
          .select()
          .eq('floor_id', floorId)
          .order('created_at');

      return response.map((json) => FiremanAxe.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load fireman axes: $e');
    }
  }

  Future<FiremanAxe> getFiremanAxeById(String axeId) async {
    try {
      final response =
          await _supabase
              .from('fireman_axes')
              .select()
              .eq('id', axeId)
              .single();
      return FiremanAxe.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching fireman axe: $e');
    }
  }

  Future<void> createFiremanAxe(
    String floorId,
    String status, {
    String? note,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _supabase.from('fireman_axes').insert({
        'floor_id': floorId,
        'status': status.isEmpty ? 'Not Working' : status,
        'note': note,
        'created_at': now,
        'updated_at': now,
      });
    } catch (e) {
      throw Exception('Failed to create fireman axe: $e');
    }
  }

  Future<void> updateFiremanAxe(
    String axeId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase
          .from('fireman_axes')
          .update({
            'status': status,
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', axeId);
    } catch (e) {
      throw Exception('Failed to update fireman axe: $e');
    }
  }

  Future<void> deleteFiremanAxe(String axeId) async {
    try {
      await _supabase.from('fireman_axes').delete().eq('id', axeId);
    } catch (e) {
      throw Exception('Failed to delete fireman axe: $e');
    }
  }

  // Hose Reel related methods
  Future<List<HoseReel>> getHoseReelsByFloorId(String floorId) async {
    try {
      final response = await _supabase
          .from('hose_reels')
          .select()
          .eq('floor_id', floorId)
          .order('created_at');

      return response.map((json) => HoseReel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load hose reels: $e');
    }
  }

  Future<HoseReel> getHoseReelById(String reelId) async {
    try {
      final response =
          await _supabase.from('hose_reels').select().eq('id', reelId).single();
      return HoseReel.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching hose reel: $e');
    }
  }

  Future<void> createHoseReel(
    String floorId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase.from('hose_reels').insert({
        'floor_id': floorId,
        'status': status,
        'note': note,
      });
    } catch (e) {
      throw Exception('Failed to create hose reel: $e');
    }
  }

  Future<void> updateHoseReel(
    String reelId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase
          .from('hose_reels')
          .update({
            'status': status,
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reelId);
    } catch (e) {
      throw Exception('Failed to update hose reel: $e');
    }
  }

  Future<void> deleteHoseReel(String reelId) async {
    try {
      await _supabase.from('hose_reels').delete().eq('id', reelId);
    } catch (e) {
      throw Exception('Failed to delete hose reel: $e');
    }
  }

  // Shut Off Nozzle related methods
  Future<List<ShutOffNozzle>> getShutOffNozzlesByFloorId(String floorId) async {
    try {
      final response = await _supabase
          .from('shut_off_nozzles')
          .select()
          .eq('floor_id', floorId)
          .order('created_at');

      return response.map((json) => ShutOffNozzle.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load shut-off nozzles: $e');
    }
  }

  Future<ShutOffNozzle> getShutOffNozzleById(String nozzleId) async {
    try {
      final response =
          await _supabase
              .from('shut_off_nozzles')
              .select()
              .eq('id', nozzleId)
              .single();
      return ShutOffNozzle.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching shut-off nozzle: $e');
    }
  }

  Future<void> createShutOffNozzle(
    String floorId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase.from('shut_off_nozzles').insert({
        'floor_id': floorId,
        'status': status,
        'note': note,
      });
    } catch (e) {
      throw Exception('Failed to create shut-off nozzle: $e');
    }
  }

  Future<void> updateShutOffNozzle(
    String nozzleId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase
          .from('shut_off_nozzles')
          .update({
            'status': status,
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', nozzleId);
    } catch (e) {
      throw Exception('Failed to update shut-off nozzle: $e');
    }
  }

  Future<void> deleteShutOffNozzle(String nozzleId) async {
    try {
      await _supabase.from('shut_off_nozzles').delete().eq('id', nozzleId);
    } catch (e) {
      throw Exception('Failed to delete shut-off nozzle: $e');
    }
  }

  // Key Glass related methods
  Future<List<KeyGlass>> getKeyGlassesByFloorId(String floorId) async {
    try {
      final response = await _supabase
          .from('key_glasses')
          .select()
          .eq('floor_id', floorId)
          .order('created_at');

      return response.map((json) => KeyGlass.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load key glasses: $e');
    }
  }

  Future<KeyGlass> getKeyGlassById(String glassId) async {
    try {
      final response =
          await _supabase
              .from('key_glasses')
              .select()
              .eq('id', glassId)
              .single();
      return KeyGlass.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching key glass: $e');
    }
  }

  Future<void> createKeyGlass(
    String floorId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase.from('key_glasses').insert({
        'floor_id': floorId,
        'status': status,
        'note': note,
      });
    } catch (e) {
      throw Exception('Failed to create key glass: $e');
    }
  }

  Future<void> updateKeyGlass(
    String glassId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase
          .from('key_glasses')
          .update({
            'status': status,
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', glassId);
    } catch (e) {
      throw Exception('Failed to update key glass: $e');
    }
  }

  Future<void> deleteKeyGlass(String glassId) async {
    try {
      await _supabase.from('key_glasses').delete().eq('id', glassId);
    } catch (e) {
      throw Exception('Failed to delete key glass: $e');
    }
  }

  // Pressure Gauge related methods
  Future<List<PressureGauge>> getPressureGaugesByFloorId(String floorId) async {
    try {
      final response = await _supabase
          .from('pressure_gauges')
          .select()
          .eq('floor_id', floorId)
          .order('created_at');

      return response.map((json) => PressureGauge.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load pressure gauges: $e');
    }
  }

  Future<PressureGauge> getPressureGaugeById(String gaugeId) async {
    try {
      final response =
          await _supabase
              .from('pressure_gauges')
              .select()
              .eq('id', gaugeId)
              .single();
      return PressureGauge.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching pressure gauge: $e');
    }
  }

  Future<void> createPressureGauge(
    String floorId,
    String status, {
    String? note,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _supabase.from('pressure_gauges').insert({
        'floor_id': floorId,
        'status': status.isEmpty ? 'Not Working' : status,
        'note': note,
        'created_at': now,
        'updated_at': now,
      });
    } catch (e) {
      throw Exception('Failed to create pressure gauge: $e');
    }
  }

  Future<void> updatePressureGauge(
    String gaugeId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase
          .from('pressure_gauges')
          .update({
            'status': status,
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', gaugeId);
    } catch (e) {
      throw Exception('Failed to update pressure gauge: $e');
    }
  }

  Future<void> deletePressureGauge(String gaugeId) async {
    try {
      await _supabase.from('pressure_gauges').delete().eq('id', gaugeId);
    } catch (e) {
      throw Exception('Failed to delete pressure gauge: $e');
    }
  }

  // ABC Extinguisher related methods
  Future<List<ABCExtinguisher>> getABCExtinguishersByFloorId(
    String floorId,
  ) async {
    try {
      final response = await _supabase
          .from('abc_extinguishers')
          .select()
          .eq('floor_id', floorId)
          .order('created_at');

      return response.map((json) => ABCExtinguisher.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load ABC extinguishers: $e');
    }
  }

  Future<ABCExtinguisher> getABCExtinguisherById(String extinguisherId) async {
    try {
      final response =
          await _supabase
              .from('abc_extinguishers')
              .select()
              .eq('id', extinguisherId)
              .single();
      return ABCExtinguisher.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching ABC extinguisher: $e');
    }
  }

  Future<void> createABCExtinguisher(
    String floorId,
    String status, {
    String? note,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _supabase.from('abc_extinguishers').insert({
        'floor_id': floorId,
        'status': status.isEmpty ? 'Not Working' : status,
        'note': note,
        'created_at': now,
        'updated_at': now,
      });
    } catch (e) {
      throw Exception('Failed to create ABC extinguisher: $e');
    }
  }

  Future<void> updateABCExtinguisher(
    String extinguisherId,
    String status, {
    String? note,
  }) async {
    try {
      await _supabase
          .from('abc_extinguishers')
          .update({
            'status': status,
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', extinguisherId);
    } catch (e) {
      throw Exception('Failed to update ABC extinguisher: $e');
    }
  }

  Future<void> deleteABCExtinguisher(String extinguisherId) async {
    try {
      await _supabase
          .from('abc_extinguishers')
          .delete()
          .eq('id', extinguisherId);
    } catch (e) {
      throw Exception('Failed to delete ABC extinguisher: $e');
    }
  }

  // Sprinkler ZCV related methods
  Future<List<SprinklerZCV>> getSprinklerZCVsByFloorId(String floorId) async {
    try {
      final response = await _supabase
          .from('sprinkler_zcvs')
          .select()
          .eq('floor_id', floorId)
          .order('created_at');

      return response.map((json) => SprinklerZCV.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load sprinkler ZCVs: $e');
    }
  }

  Future<SprinklerZCV> getSprinklerZCVById(String zcvId) async {
    try {
      final response =
          await _supabase
              .from('sprinkler_zcvs')
              .select()
              .eq('id', zcvId)
              .single();
      return SprinklerZCV.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching sprinkler ZCV: $e');
    }
  }

  Future<void> createSprinklerZCV(
    String floorId,
    String status, {
    String? note,
  }) async {
    try {
      if (status != 'Open' && status != 'Close') {
        throw Exception('Status must be either "Open" or "Close"');
      }

      final now = DateTime.now().toIso8601String();
      await _supabase.from('sprinkler_zcvs').insert({
        'floor_id': floorId,
        'status': status,
        'note': note,
        'created_at': now,
        'updated_at': now,
      });
    } catch (e) {
      throw Exception('Failed to create sprinkler ZCV: $e');
    }
  }

  Future<void> updateSprinklerZCV(
    String zcvId,
    String status, {
    String? note,
  }) async {
    try {
      if (status != 'Open' && status != 'Close') {
        throw Exception('Status must be either "Open" or "Close"');
      }

      await _supabase
          .from('sprinkler_zcvs')
          .update({
            'status': status,
            'note': note,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', zcvId);
    } catch (e) {
      throw Exception('Failed to update sprinkler ZCV: $e');
    }
  }

  Future<void> deleteSprinklerZCV(String zcvId) async {
    try {
      await _supabase.from('sprinkler_zcvs').delete().eq('id', zcvId);
    } catch (e) {
      throw Exception('Failed to delete sprinkler ZCV: $e');
    }
  }

  // Smoke Detector Methods
  Future<List<SmokeDetector>> getSmokeDetectorsByFloorId(String floorId) async {
    final response = await _supabase
        .from('smoke_detectors')
        .select()
        .eq('floor_id', floorId);

    return (response as List)
        .map((json) => SmokeDetector.fromJson(json))
        .toList();
  }

  Future<void> createSmokeDetector(
    String floorId,
    String status, {
    String? note,
  }) async {
    await _supabase.from('smoke_detectors').insert({
      'floor_id': floorId,
      'status': status,
      'note': note,
    });
  }

  Future<void> updateSmokeDetector(
    String id,
    String status, {
    String? note,
  }) async {
    await _supabase
        .from('smoke_detectors')
        .update({
          'status': status,
          'note': note,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteSmokeDetector(String id) async {
    await _supabase.from('smoke_detectors').delete().eq('id', id);
  }

  // Heat Detector Methods
  Future<List<HeatDetector>> getHeatDetectorsByFloorId(String floorId) async {
    final response = await _supabase
        .from('heat_detectors')
        .select()
        .eq('floor_id', floorId);

    return (response as List)
        .map((json) => HeatDetector.fromJson(json))
        .toList();
  }

  Future<void> createHeatDetector(
    String floorId,
    String status, {
    String? note,
  }) async {
    await _supabase.from('heat_detectors').insert({
      'floor_id': floorId,
      'status': status,
      'note': note,
    });
  }

  Future<void> updateHeatDetector(
    String id,
    String status, {
    String? note,
  }) async {
    await _supabase
        .from('heat_detectors')
        .update({
          'status': status,
          'note': note,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteHeatDetector(String id) async {
    await _supabase.from('heat_detectors').delete().eq('id', id);
  }

  // Flasher Hooter Alarm Methods
  Future<List<FlasherHooterAlarm>> getFlasherHooterAlarmsByFloorId(
    String floorId,
  ) async {
    final response = await _supabase
        .from('flasher_hooter_alarms')
        .select()
        .eq('floor_id', floorId);

    return (response as List)
        .map((json) => FlasherHooterAlarm.fromJson(json))
        .toList();
  }

  Future<void> createFlasherHooterAlarm(
    String floorId,
    String status, {
    String? note,
  }) async {
    await _supabase.from('flasher_hooter_alarms').insert({
      'floor_id': floorId,
      'status': status,
      'note': note,
    });
  }

  Future<void> updateFlasherHooterAlarm(
    String id,
    String status, {
    String? note,
  }) async {
    await _supabase
        .from('flasher_hooter_alarms')
        .update({
          'status': status,
          'note': note,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteFlasherHooterAlarm(String id) async {
    await _supabase.from('flasher_hooter_alarms').delete().eq('id', id);
  }

  // Control Module Methods
  Future<List<ControlModule>> getControlModulesByFloorId(String floorId) async {
    final response = await _supabase
        .from('control_modules')
        .select()
        .eq('floor_id', floorId);

    return (response as List)
        .map((json) => ControlModule.fromJson(json))
        .toList();
  }

  Future<void> createControlModule(
    String floorId,
    String status, {
    String? note,
  }) async {
    await _supabase.from('control_modules').insert({
      'floor_id': floorId,
      'status': status,
      'note': note,
    });
  }

  Future<void> updateControlModule(
    String id,
    String status, {
    String? note,
  }) async {
    await _supabase
        .from('control_modules')
        .update({
          'status': status,
          'note': note,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteControlModule(String id) async {
    await _supabase.from('control_modules').delete().eq('id', id);
  }

  // Flow Switch Methods
  Future<List<FlowSwitch>> getFlowSwitchesByFloorId(String floorId) async {
    final response = await _supabase
        .from('flow_switches')
        .select()
        .eq('floor_id', floorId);

    return (response as List).map((json) => FlowSwitch.fromJson(json)).toList();
  }

  Future<void> createFlowSwitch(
    String floorId,
    String status, {
    String? note,
  }) async {
    await _supabase.from('flow_switches').insert({
      'floor_id': floorId,
      'status': status,
      'note': note,
    });
  }

  Future<void> updateFlowSwitch(
    String id,
    String status, {
    String? note,
  }) async {
    await _supabase
        .from('flow_switches')
        .update({
          'status': status,
          'note': note,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteFlowSwitch(String id) async {
    await _supabase.from('flow_switches').delete().eq('id', id);
  }

  // Monitor Module Methods
  Future<List<MonitorModule>> getMonitorModulesByFloorId(String floorId) async {
    final response = await _supabase
        .from('monitor_module')
        .select()
        .eq('floor_id', floorId)
        .order('created_at', ascending: false);

    return response.map((json) => MonitorModule.fromJson(json)).toList();
  }

  Future<void> createMonitorModule(
    String floorId,
    String status, {
    String? note,
  }) async {
    await _supabase.from('monitor_module').insert({
      'floor_id': floorId,
      'status': status,
      'note': note,
    });
  }

  Future<void> updateMonitorModule(
    String id,
    String status, {
    String? note,
  }) async {
    await _supabase
        .from('monitor_module')
        .update({
          'status': status,
          'note': note,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteMonitorModule(String id) async {
    await _supabase.from('monitor_module').delete().eq('id', id);
  }

  // Telephone Jack Methods
  Future<List<TelephoneJack>> getTelephoneJacksByFloorId(String floorId) async {
    final response = await _supabase
        .from('telephone_jack')
        .select()
        .eq('floor_id', floorId)
        .order('created_at', ascending: false);

    return response.map((json) => TelephoneJack.fromJson(json)).toList();
  }

  Future<void> createTelephoneJack(
    String floorId,
    String status, {
    String? note,
  }) async {
    await _supabase.from('telephone_jack').insert({
      'floor_id': floorId,
      'status': status,
      'note': note,
    });
  }

  Future<void> updateTelephoneJack(
    String id,
    String status, {
    String? note,
  }) async {
    await _supabase
        .from('telephone_jack')
        .update({
          'status': status,
          'note': note,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteTelephoneJack(String id) async {
    await _supabase.from('telephone_jack').delete().eq('id', id);
  }

  // Speaker Methods
  Future<List<Speaker>> getSpeakersByFloorId(String floorId) async {
    final response = await _supabase
        .from('speaker')
        .select()
        .eq('floor_id', floorId)
        .order('created_at', ascending: false);

    return response.map((json) => Speaker.fromJson(json)).toList();
  }

  Future<void> createSpeaker(
    String floorId,
    String status, {
    String? note,
  }) async {
    await _supabase.from('speaker').insert({
      'floor_id': floorId,
      'status': status,
      'note': note,
    });
  }

  Future<void> updateSpeaker(String id, String status, {String? note}) async {
    await _supabase
        .from('speaker')
        .update({
          'status': status,
          'note': note,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteSpeaker(String id) async {
    await _supabase.from('speaker').delete().eq('id', id);
  }

  // Building Accessories Methods
  Future<BuildingAccessories?> getBuildingAccessoriesBySiteId(
    String siteId,
  ) async {
    try {
      final response =
          await _supabase
              .from('building_accessories')
              .select()
              .eq('site_id', siteId)
              .maybeSingle();

      return response != null ? BuildingAccessories.fromJson(response) : null;
    } catch (e) {
      throw Exception('Error fetching building accessories: $e');
    }
  }

  Future<void> createBuildingAccessories(
    String siteId, {
    String fireAlarmPanelStatus = 'Working',
    String repeaterPanelStatus = 'Working',
    String batteryStatus = 'Working',
    String liftIntegrationRelayStatus = 'Working',
    String accessIntegrationStatus = 'Working',
    String pressFanIntegrationStatus = 'Working',
    String? notes,
  }) async {
    try {
      await _supabase.from('building_accessories').insert({
        'site_id': siteId,
        'fire_alarm_panel_status': fireAlarmPanelStatus,
        'repeater_panel_status': repeaterPanelStatus,
        'battery_status': batteryStatus,
        'lift_integration_relay_status': liftIntegrationRelayStatus,
        'access_integration_status': accessIntegrationStatus,
        'press_fan_integration_status': pressFanIntegrationStatus,
        'notes': notes,
      });
    } catch (e) {
      throw Exception('Error creating building accessories: $e');
    }
  }

  Future<void> updateBuildingAccessories(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _supabase
          .from('building_accessories')
          .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw Exception('Error updating building accessories: $e');
    }
  }

  // File Operations
  Future<void> uploadFile(String bucket, String fileName, File file) async {
    await _supabase.storage.from(bucket).upload(fileName, file);
  }


  String getFileUrl(String bucket, String fileName) {
    return _supabase.storage.from(bucket).getPublicUrl(fileName);
  }

  // Add these new methods for operational tests
  Future<List<Map<String, dynamic>>> getOperationalTests(String siteId) async {
    try {
      final response = await _supabase
          .from('operational_tests')
          .select()
          .eq('site_id', siteId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting operational tests: $e');
      rethrow;
    }
  }

  Future<void> saveOperationalTest({
    required String siteId,
    required String testType,
    required double standardValue,
    required double observedValue,
    required String comments,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if test already exists
      final existingTest =
          await _supabase
              .from('operational_tests')
              .select()
              .eq('site_id', siteId)
              .eq('test_type', testType)
              .maybeSingle();

      if (existingTest != null) {
        // Update existing test
        await _supabase
            .from('operational_tests')
            .update({
              'standard_value': standardValue,
              'observed_value': observedValue,
              'comments': comments,
              'updated_by': user.id,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingTest['id']);
      } else {
        // Create new test with UUID
        await _supabase.from('operational_tests').insert({
          'id': _uuid.v4(),
          'site_id': siteId,
          'test_type': testType,
          'standard_value': standardValue,
          'observed_value': observedValue,
          'comments': comments,
          'created_by': user.id,
          'updated_by': user.id,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Error saving operational test: $e');
      rethrow;
    }
  }

  // Add these new methods for engine inspections
  Future<List<Map<String, dynamic>>> getEngineInspections(String siteId) async {
    try {
      final response = await _supabase
          .from('engine_inspections')
          .select()
          .eq('site_id', siteId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting engine inspections: $e');
      rethrow;
    }
  }

  Future<void> saveEngineInspection({
    required String siteId,
    required String inspectionType,
    required String value,
    required String comments,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if inspection already exists
      final existingInspection =
          await _supabase
              .from('engine_inspections')
              .select()
              .eq('site_id', siteId)
              .eq('inspection_type', inspectionType)
              .maybeSingle();

      if (existingInspection != null) {
        // Update existing inspection
        await _supabase
            .from('engine_inspections')
            .update({
              'value': value,
              'comments': comments,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingInspection['id']);
      } else {
        // Create new inspection
        await _supabase.from('engine_inspections').insert({
          'site_id': siteId,
          'inspection_type': inspectionType,
          'value': value,
          'comments': comments,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Error saving engine inspection: $e');
      rethrow;
    }
  }

  Future<String> uploadAreaReport(
    String areaId,
    File reportFile, {
    String? reportName,
  }) async {
    final fileExt = reportFile.path.split('.').last;
    final fileName =
        reportName != null
            ? '$reportName.$fileExt'
            : '$areaId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    await _supabase.storage.from('areareports').upload(fileName, reportFile);
    final publicUrl = _supabase.storage
        .from('areareports')
        .getPublicUrl(fileName);

    final timestamp = DateTime.now().toUtc().toIso8601String();
    await _supabase.from('area_reports').insert({
      'area_id': areaId,
      'file_name': fileName,
      'report_url': publicUrl,
      'generated_at': timestamp,
      'updated_at': timestamp,
    });

    return publicUrl;
  }

  Future<List<Map<String, dynamic>>> getAreaReports(String areaId) async {
    final response = await _supabase
        .from('area_reports')
        .select()
        .eq('area_id', areaId)
        .order('generated_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }



  Future<List<Map<String, dynamic>>> getBuildingAccessories(
    String siteId,
  ) async {
    try {
      final response = await Supabase.instance.client
          .from('building_accessories')
          .select()
          .eq('site_id', siteId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching building accessories: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCustomBuildingAccessories(
    String siteId,
  ) async {
    try {
      final response = await Supabase.instance.client
          .from('custom_building_accessories')
          .select()
          .eq('site_id', siteId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching custom building accessories: $e');
      return [];
    }
  }

  uploadBytes(String s, String fileName, Uint8List uint8list) {}


  // qr scanning for the dyanamic premise creation

  Future<String> generateAndUploadQrImage(String premiseId, {String? premiseName}) async {
    try {
      // Create a data object that includes both the ID and name
      final Map<String, dynamic> qrData = {
        'id': premiseId,
        'name': premiseName ?? 'Unknown Premise',
      };
      
      // Convert to JSON string for QR code
      final String qrDataString = jsonEncode(qrData);
      
      final qrValidationResult = QrValidator.validate(
        data: qrDataString,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M, // Medium error correction for better readability
      );

      if (qrValidationResult.status != QrValidationStatus.valid) {
        throw Exception("Invalid QR data for premise: $premiseId");
      }

      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
        gapless: true,
      );

      // Generate QR code image
      final image = await painter.toImage(300);
      final ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to generate QR code image');
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Upload to Supabase Storage
      final fileName = 'public/$premiseId.png';
      
      // First try to remove any existing file to avoid duplicate errors
      try {
        await Supabase.instance.client.storage
            .from('qr-codes')
            .remove([fileName]);
        print('Removed existing QR code file');
      } catch (e) {
        // It's okay if the file doesn't exist yet
        print('No existing QR code file to remove or error removing: $e');
      }
      
      // Now upload the new file
      await Supabase.instance.client.storage
          .from('qr-codes')
          .uploadBinary(fileName, pngBytes, fileOptions: const FileOptions(contentType: 'image/png'));

      // Return public URL
      final publicUrl = Supabase.instance.client.storage.from('qr-codes').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      print('Error generating or uploading QR code: $e');
      throw Exception('Failed to generate or upload QR code: $e');
    }
  }





  final SupabaseClient _client = Supabase.instance.client;

  Future<Premise> createPremise(String contractorId, Map<String, dynamic> data, {required String name, required Map additionalData}) async {
    try {
      print('Creating premise for contractor: $contractorId');
      // Insert the premise with a placeholder qr_url to satisfy NOT NULL
      final response = await _supabase.from('premises').insert({
        'contractor_id': contractorId,
        'name': data['name'],
        'data': data,
        'qr_url': 'pending' // Placeholder to satisfy NOT NULL
      }).select('id, contractor_id, data, contractor(name)').single();

      final premiseId = response['id'] as String;
      print('Premise created with ID: $premiseId');

      // Generate and upload QR code
      String qrUrl;
      try {
        print('Generating and uploading QR code for premise: $premiseId with name: ${data['name']}');
        qrUrl = await generateAndUploadQrImage(premiseId, premiseName: data['name']);
        print('Successfully generated QR URL: $qrUrl');
      } catch (e) {
        print('Error generating or uploading QR code for premise $premiseId: $e');
        qrUrl = 'pending'; // Fallback value
      }

      // Update the premise with the QR URL
      print('Updating premise $premiseId with qr_url: $qrUrl');
      final updateResponse = await _supabase.from('premises').update({
        'qr_url': qrUrl,
      }).eq('id', premiseId).select('id, qr_url'); // Select to verify update
      print('Update response: $updateResponse');

      // Fetch the updated premise
      final updatedResponse = await _supabase
          .from('premises')
          .select('id, contractor_id, data, qr_url, contractor(name)')
          .eq('id', premiseId)
          .single();

      final contractor = updatedResponse['contractor'] as Map<String, dynamic>? ?? {'name': 'Unknown'};
      final premise = Premise.fromMap({
        ...updatedResponse,
        'contractor_name': contractor['name'],
      });

      print('Premise retrieved with QR URL: ${premise.qr_Url}');
      return premise;
    } catch (e) {
      print('Error in createPremise: $e');
      throw Exception('Failed to create premise: $e');
    }
  }

  Future<List<Premise>> getPremises() async {
    try {
      final response = await _supabase
          .from('premises')
          .select('id, contractor_id, data, contractor(name)')
          .order('created_at', ascending: false);
      return response.map((map) {
        final contractor = map['contractor'] as Map<String, dynamic>? ?? {'name': 'Unknown'};
        return Premise.fromMap({
          ...map,
          'contractor_name': contractor['name'],
        });
      }).toList();
    } catch (e) {
      throw Exception('Error fetching premises: $e');
    }
  }

  Future<void> deletePremise(String id) async {
    await _supabase.from('premises').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getContractors() async {
    final response = await _supabase.from('contractor').select('id, name');
    return response as List<Map<String, dynamic>>;
  }

  Future<List<Section>> getSections(String premiseId) async {
    final response = await Supabase.instance.client
        .from('sections')
        .select()
        .eq('premise_id', premiseId);
    return response.map((data) => Section.fromJson(data)).toList();
  }

  // Additional method to regenerate QR code if needed
  Future<String> regenerateQrCode(String premiseId) async {
    try {
      // First, get the premise details to include the name in the QR code
      final premiseResponse = await _client
          .from('premises')
          .select('id, data')
          .eq('id', premiseId)
          .single();
      
      final premiseData = premiseResponse['data'] as Map<String, dynamic>;
      final premiseName = premiseData['name'] as String? ?? 'Unknown Premise';
      
      // Generate QR code with premise name included
      final qrUrl = await generateAndUploadQrImage(premiseId, premiseName: premiseName);

      // Update the premise with the new QR URL
      await _client
          .from('premises')
          .update({'qr_url': qrUrl})
          .eq('id', premiseId);

      return qrUrl;
    } catch (e) {
      print('Error in regenerateQrCode: $e');
      throw Exception('Failed to regenerate QR code: $e');
    }
  }

  // Future<List<Section>> getSections(String premiseId) async {
  //   final response = await Supabase.instance.client
  //       .from('sections')
  //       .select()
  //       .eq('premise_id', premiseId);
  //   return response.map((data) => Section.fromJson(data)).toList();
  // }

  Future<void> createSection(String premiseId, Map<String, dynamic> data) async {
    await Supabase.instance.client
        .from('sections')
        .insert({
          'premise_id': premiseId, 
          'name': data['name'],
          'data': data
        });
  }

  Future<void> updateSection(String sectionId, Map<String, dynamic> data) async {
    await Supabase.instance.client
        .from('sections')
        .update({'data': data})
        .eq('id', sectionId);
  }



  // Subsections
  Future<List<Subsection>> getSubsections(String sectionId) async {
    try {
      final response = await _supabase
          .from('subsections')
          .select('id, section_id, name, data')
          .eq('section_id', sectionId)
          .order('created_at', ascending: false);

      return response.map((map) => Subsection.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Error fetching subsections: $e');
    }
  }


  Future<Subsection> createSubsection(String sectionId, Map<String, dynamic> data) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('subsections')
          .insert({
        'section_id': sectionId,
        'name': data['name'],
        'data': data,
      })
          .select('id, section_id, name, data')
          .single();

      return Subsection.fromMap(response);
    } catch (e) {
      throw Exception('Error creating subsection: $e');
    }
  }


  // Products
  Future<List<Product>> getProducts(String subsectionId) async {
    try {
      final response = await _supabase
          .from('subsections_products')
          .select('id, subsection_id, name, data, created_at')
          .eq('subsection_id', subsectionId)
          .order('created_at', ascending: false);

      return response.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Error fetching products: $e');
    }
  }

  Future<List<SectionProduct>> getSectionProducts(String sectionId) async {
    final response = await _supabase
        .from('section_products')
        .select()
        .eq('section_id', sectionId)
        .order('created_at', ascending: false);

    if (response != null && response is List) {
      return response
          .map((map) => SectionProduct.fromMap(map as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load products');
    }
  }


  Future<void> createSectionProduct(SectionProduct product) async {
    final response = await Supabase.instance.client
        .from('section_products') // Make sure this matches your Supabase table name
        .insert({
      'id': product.id, // You can use `uuid` from Dart if you generate manually
      'section_id': product.sectionId,
      'name': product.name,
      'quantity': product.quantity,
      'data': product.details,
      'created_at': product.createdAt.toIso8601String(), // Optional, Supabase can auto-generate this
    });

    if (response != null && response.error != null) {
      throw Exception('Failed to create section product: ${response.error!.message}');
    }
  }



  Future<Product> createProduct(String subsectionId, Map<String, dynamic> data) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase.from('subsections_products').insert({
        'subsection_id': subsectionId,
        'name': data['name'],
        'data': data,
      }).select('id, subsection_id, name, data, created_at').single();

      return Product.fromMap(response);
    } catch (e) {
      throw Exception('Error creating product: $e');
    }
  }


  getProductsBySection(String id) {}


  Future<void> createPremiseProduct(String premiseId, Map<String, dynamic> data) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabase.from('premise_products').insert({
      'contractor_id': user.id,
      'premise_id': premiseId,
      'name': data['name'],
      'quantity': data['quantity'],
      'details': data['details'],  // JSON type: can contain any key-values
    });
  }

  Future<List<PremiseProduct>> getProductsByPremise(String premiseId) async {
    final response = await _supabase
        .from('premise_products')
        .select()
        .eq('premise_id', premiseId)
        .order('created_at', ascending: false);

    final data = response as List;
    return data.map((json) => PremiseProduct.fromJson(json)).toList();
  }



  fetchProductsByPremise(String id) {}






}
