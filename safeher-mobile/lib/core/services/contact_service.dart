import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/contact_model.dart';
import '../network/api_client.dart';

class ContactApiService {
  final Dio _dio = ApiClient.client;

  Future<List<ContactModel>> getContacts() async {
    final response = await _dio.get(ApiConstants.contacts);
    final data = response.data['data'] as List<dynamic>;
    return data.map((json) => ContactModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<ContactModel> getContact(int id) async {
    final response = await _dio.get(ApiConstants.contactDetail(id));
    return ContactModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<ContactModel> createContact(Map<String, dynamic> contactData) async {
    final response = await _dio.post(ApiConstants.contacts, data: contactData);
    return ContactModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<ContactModel> updateContact(int id, Map<String, dynamic> contactData) async {
    final response = await _dio.put(ApiConstants.contactDetail(id), data: contactData);
    return ContactModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteContact(int id) async {
    await _dio.delete(ApiConstants.contactDetail(id));
  }
}
