import '../../../../core/services/api_service.dart';
import '../models/material_stock_model.dart';
import '../models/material_quotation_model.dart';

/// Thin wrapper around ApiService's Stage 2.1 methods, kept so existing
/// controllers can keep calling Stage21ApiService.xxx without changes.
class Stage21ApiService {
  // ── Material Stock ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchMaterialStocks({
    required int projectId,
    int page = 1,
    int perPage = 15,
    String? search,
  }) {
    return ApiService.fetchMaterialStocks(
      projectId: projectId,
      page: page,
      perPage: perPage,
      search: search,
    );
  }

  static Future<MaterialStockModel> fetchMaterialStock(
      int projectId, int id) async {
    final response = await ApiService.fetchMaterialStock(projectId, id);
    return MaterialStockModel.fromJson(response['data']);
  }

  static Future<String> fetchNextStockNo(int projectId) {
    return ApiService.fetchNextStockNo(projectId);
  }

  static Future<MaterialStockModel> createMaterialStock({
    required int projectId,
    required String registerMonth,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await ApiService.createMaterialStock(
      projectId: projectId,
      registerMonth: registerMonth,
      items: items,
    );
    return MaterialStockModel.fromJson(response['data']);
  }

  static Future<MaterialStockModel> updateMaterialStock({
    required int projectId,
    required int id,
    required String registerMonth,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await ApiService.updateMaterialStock(
      projectId: projectId,
      id: id,
      registerMonth: registerMonth,
      items: items,
    );
    return MaterialStockModel.fromJson(response['data']);
  }

  static Future<void> deleteMaterialStock(int projectId, int id) {
    return ApiService.deleteMaterialStock(projectId, id);
  }

  // ── Material Quotation ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchMaterialQuotations({
    required int projectId,
    int page = 1,
    int perPage = 15,
    String? search,
  }) {
    return ApiService.fetchMaterialQuotations(
      projectId: projectId,
      page: page,
      perPage: perPage,
      search: search,
    );
  }

  static Future<MaterialQuotationModel> fetchMaterialQuotation(
      int projectId, int id) async {
    final response = await ApiService.fetchMaterialQuotation(projectId, id);
    return MaterialQuotationModel.fromJson(response['data']);
  }

  static Future<String> fetchNextQuotationNo(int projectId) {
    return ApiService.fetchNextQuotationNo(projectId);
  }

  static Future<MaterialQuotationModel> createMaterialQuotation({
    required int projectId,
    required String registerMonth,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await ApiService.createMaterialQuotation(
      projectId: projectId,
      registerMonth: registerMonth,
      items: items,
    );
    return MaterialQuotationModel.fromJson(response['data']);
  }

  static Future<MaterialQuotationModel> updateMaterialQuotation({
    required int projectId,
    required int id,
    required String registerMonth,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await ApiService.updateMaterialQuotation(
      projectId: projectId,
      id: id,
      registerMonth: registerMonth,
      items: items,
    );
    return MaterialQuotationModel.fromJson(response['data']);
  }

  static Future<void> deleteMaterialQuotation(int projectId, int id) {
    return ApiService.deleteMaterialQuotation(projectId, id);
  }
}