import os

path = r'c:\App Development\PMS\lib\core\services\appointment_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Chunk 1
old_1 = """        final c = ConsultationModel.fromRecord(record);
        // Return regardless of status — ongoing = resume, completed = view only.
        // Never create a second consultation for the same appointment.
        return (c.id, false);
      } catch (_) {"""

new_1 = """        final c = ConsultationModel.fromRecord(record);
        if (c.isDeleted) {
          // If the linked consultation is soft-deleted, ignore it and fall through to create a new one.
        } else {
          // Return regardless of status — ongoing = resume, completed = view only.
          // Never create a second consultation for the same appointment unless the old one was deleted.
          return (c.id, false);
        }
      } catch (_) {"""

content = content.replace(old_1, new_1)

# Chunk 2
old_2 = """          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Restores a soft-deleted consultation"""

new_2 = """          }
        } catch (_) {}
      }
    } catch (_) {}

    // 4. Find associated appointment and reset consultation_form_saved
    try {
      final apts = await pb.collection(PBCollections.appointments).getList(
        filter: 'linked_consultation_id = "${consultationId}"',
      );
      for (final apt in apts.items) {
        await pb.collection(PBCollections.appointments).update(
          apt.id,
          body: {
            'consultation_form_saved': false,
          },
        );
      }
    } catch (_) {}
  }

  /// Restores a soft-deleted consultation"""

content = content.replace(old_2, new_2)

# Chunk 3
old_3 = """          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Permanently deletes a consultation"""

new_3 = """          }
        } catch (_) {}
      }
    } catch (_) {}

    // 4. Find associated appointment and restore consultation_form_saved if it was completed
    try {
      final record = await pb.collection(PBCollections.consultations).getOne(consultationId);
      final status = record.getStringValue('status');
      
      final apts = await pb.collection(PBCollections.appointments).getList(
        filter: 'linked_consultation_id = "${consultationId}"',
      );
      for (final apt in apts.items) {
        await pb.collection(PBCollections.appointments).update(
          apt.id,
          body: {
            'consultation_form_saved': status == 'completed',
          },
        );
      }
    } catch (_) {}
  }

  /// Permanently deletes a consultation"""

content = content.replace(old_3, new_3)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")
