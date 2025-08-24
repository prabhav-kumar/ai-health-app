class AIModelsConfig {
  // Update this URL after deploying your models to Hugging Face Spaces
  static const String baseUrl = "https://prabhav-kumar-medical-ai-health-analysis.hf.space";
  
  // Available model endpoints
  static const Map<String, String> modelEndpoints = {
    'auto': '/analyze/auto',
    'brain_classification': '/brain_classification',
    'brain_segmentation': '/brain_segmentation',
    'chest_classification': '/chest_classification',
    'fracture_localization': '/fracture_localization',
    'medical_classification': '/medical_classification',
    'retinopathy_classification': '/retinopathy_classification',
  };
  
  // Get full URL for a specific model
  static String getModelUrl(String modelType) {
    return '$baseUrl${modelEndpoints[modelType] ?? ''}';
  }

  static String getAutoUrl() => '$baseUrl${modelEndpoints['auto']!}';
}