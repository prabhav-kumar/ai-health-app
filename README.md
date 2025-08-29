# AI Medical Health Analysis App

A comprehensive Flutter application that leverages state-of-the-art medical AI models and Gemini API intelligence for analyzing various medical imaging modalities. The app integrates with Hugging Face Spaces for model inference and provides an intuitive interface for medical image analysis.

## Features

- **Multi-Modal Medical Image Analysis**: Support for various medical imaging types
- **Real-time AI Analysis**: Powered by 6 specialized medical AI models
- **Gemini-Powered AI Intelligence**: Context-aware medical insights and assistance
- **User Authentication**: Secure login with Firebase
- **Interactive UI**: Modern, responsive design with real-time feedback
- **Chat Interface**: AI-powered health assistant for additional guidance
- **Cross-Platform**: Works on Android, iOS, and Web

## AI Models

All models are deployed on Hugging Face Spaces and accessible via API. The models include:

1. **Medical Classification Model**
   - Classifies medical images into different modalities
   - Categories: Brain MRI, Chest X-ray, Bone X-ray, Fundus Images
   - Architecture: DenseNet121

2. **Brain Tumor Classification**
   - Analyzes brain MRI scans
   - Detects: Glioma, Meningioma, Pituitary tumors
   - Architecture: Modified ResNet18

3. **Brain Tumor Segmentation**
   - Precise tumor region localization
   - Generates segmentation masks
   - Architecture: U-Net based architecture

4. **Chest X-ray Analysis**
   - Diagnoses various chest conditions
   - Detects: COVID-19, Pneumonia, Tuberculosis
   - Provides confidence scores for each condition

5. **Diabetic Retinopathy Classification**
   - Analyzes fundus images
   - Grades retinopathy severity
   - 5-class classification (No DR to Proliferative DR)

6. **Fracture Localization**
   - Detects and localizes bone fractures
   - Provides visual annotations
   - Real-time detection capabilities

## Getting Started

1. Clone the repository
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Set up Firebase:
   - Create a Firebase project
   - Add your `google-services.json` and `GoogleService-Info.plist`
   - Enable Authentication

4. Configure environment variables:
   Create a `.env` file with:
   ```
   HUGGINGFACE_TOKEN=your_token_here
   GEMINI_API_KEY=your_key_here
   ```

## Model Access

The model files are not included in this repository due to size constraints. If you need access to the model files for research or development purposes, please contact:

Email: k.prabhav2005@gmail.com

## Technical Details

- **Frontend**: Flutter
- **Backend**: Hugging Face Spaces
- **Authentication**: Firebase
- **Intelligence Layer**: Gemini API
- **AI Models**: PyTorch, TensorFlow
- **API Integration**: REST APIs

## Model Training Notebooks

The training code for all models is available in separate repositories:
- Brain Classification: `brain_classification_code.ipynb`
- Brain Segmentation: `brain_segmentation_code.ipynb`
- Chest Classification: `chest_classification_code.ipynb`
- Medical Classification: `medical_classification_code.ipynb`
- Fracture Localization: `fracture_localization_code.ipynb`
- Diabetic Retinopathy Classification: `retinopathy_classification_code.ipynb`

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- Thanks to Hugging Face for hosting the models
- Medical imaging datasets providers
- Flutter and Firebase teams

## Contact

K Prabhav Kumar - k.prabhav2005@gmail.com
