import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {

  final TextEditingController brandController =
    TextEditingController();

  final TextEditingController modelController =
      TextEditingController();

  final TextEditingController yearController =
      TextEditingController();

  final TextEditingController engineSizeController =
      TextEditingController();

  final TextEditingController enginePowerController =
      TextEditingController();

  final TextEditingController consumptionController =
      TextEditingController();

  final TextEditingController fuelPriceController =
      TextEditingController();

  String fuelType = 'Gasoline';
  String transmission = 'Manual';

  @override
  void dispose() {
    brandController.dispose();
    modelController.dispose();
    yearController.dispose();
    engineSizeController.dispose();
    enginePowerController.dispose();
    consumptionController.dispose();
    fuelPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicle'),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            TextField(
              controller: brandController,
              decoration: const InputDecoration(
                labelText: 'Brand',
                hintText: 'Example: Renault',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: modelController,
              decoration: const InputDecoration(
                labelText: 'Model',
                hintText: 'Example: Rapid',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Year',
                hintText: 'Example: 1998',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: engineSizeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Engine size',
                hintText: 'Example: 1.4',
                suffixText: 'L',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: enginePowerController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Engine power',
                hintText: 'Example: 75',
                suffixText: 'HP',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: fuelType,

              decoration: const InputDecoration(
                labelText: 'Fuel type',
                border: OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem(
                  value: 'Gasoline',
                  child: Text('Gasoline'),
                ),
                DropdownMenuItem(
                  value: 'Diesel',
                  child: Text('Diesel'),
                ),
              ],

              onChanged: (value) {
                setState(() {
                  fuelType = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: transmission,

              decoration: const InputDecoration(
                labelText: 'Transmission',
                border: OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem(
                  value: 'Manual',
                  child: Text('Manual'),
                ),
                DropdownMenuItem(
                  value: 'Automatic',
                  child: Text('Automatic'),
                ),
              ],

              onChanged: (value) {
                setState(() {
                  transmission = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            TextField(
              controller: consumptionController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Fuel consumption',
                hintText: 'Example: 7.0',
                suffixText: 'L / 100 km',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: fuelPriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Fuel price',
                hintText: 'Example: 1.50',
                prefixText: '\$ ',
                suffixText: '/ L',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                onPressed: () async {
                  final brand = brandController.text.trim();
                  final model = modelController.text.trim();

                  final year = int.tryParse(yearController.text);
                  final engineSize =
                      double.tryParse(engineSizeController.text);
                  final enginePower =
                      int.tryParse(enginePowerController.text);

                  final consumption =
                      double.tryParse(consumptionController.text);

                  final price =
                      double.tryParse(fuelPriceController.text);

                  if (brand.isEmpty ||
                      model.isEmpty ||
                      consumption == null ||
                      price == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please fill in the required fields correctly.',
                        ),
                      ),
                    );

                    return;
                  }
                  final user = Supabase.instance.client.auth.currentUser;

                  print('LOGGED IN USER: ${user?.id}');
                  print('LOGGED IN EMAIL: ${user?.email}');
                  
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You must be logged in to save a vehicle.'),
                      ),
                    );

                    return;
                  }

                  try {
                    await Supabase.instance.client
                        .from('vehicles')
                        .insert({
                      'user_id': user.id,
                      'brand': brand,
                      'model': model,
                      'year': year,
                      'engine_size': engineSize,
                      'engine_power': enginePower,
                      'fuel_type': fuelType,
                      'transmission': transmission,
                      'fuel_consumption': consumption,
                      'fuel_price': price,
                    });

                    brandController.clear();
                    modelController.clear();
                    yearController.clear();
                    engineSizeController.clear();
                    enginePowerController.clear();
                    consumptionController.clear();
                    fuelPriceController.clear();

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Vehicle saved successfully! 🚗',
                        ),
                      ),
                    );
                  } catch (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error saving vehicle: $error',
                        ),
                      ),
                    );
                  }
                },

                icon: const Icon(Icons.save),

                label: const Text(
                  'Save Vehicle',
                ),
              ),
            ),
          ],
        )
      ),
    );
  }
}