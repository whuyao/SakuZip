#ifndef SAKUZIP_ARCHIVE_H
#define SAKUZIP_ARCHIVE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct yc_archive_control yc_archive_control;

typedef struct yc_archive_info {
    uint64_t total_uncompressed_size;
    uint32_t entry_count;
    uint8_t is_encrypted;
    uint8_t uses_aes;
    uint8_t uses_traditional_encryption;
} yc_archive_info;

typedef void (*yc_archive_progress_cb)(
    double progress,
    const char *entry_name,
    void *userdata
);

enum {
    YC_ARCHIVE_OK = 0,
    YC_ARCHIVE_CANCELLED = -20001,
    YC_ARCHIVE_UNSAFE_ENTRY = -20002,
    YC_ARCHIVE_PASSWORD_REQUIRED = -20003
};

enum {
    YC_ARCHIVE_ENCRYPTION_NONE = 0,
    YC_ARCHIVE_ENCRYPTION_TRADITIONAL = 1,
    YC_ARCHIVE_ENCRYPTION_AES256 = 2
};

yc_archive_control *yc_archive_control_create(void);
void yc_archive_control_delete(yc_archive_control **control);
void yc_archive_control_set_paused(yc_archive_control *control, int paused);
void yc_archive_control_cancel(yc_archive_control *control);

int32_t yc_archive_inspect(
    const char *archive_path,
    yc_archive_info *info,
    char *unsafe_entry,
    size_t unsafe_entry_capacity
);

int32_t yc_archive_create(
    const char *source_path,
    const char *destination_path,
    const uint8_t *password,
    size_t password_length,
    int encryption_mode,
    int keep_parent_folder,
    int compression_level,
    uint64_t total_uncompressed_size,
    yc_archive_control *control,
    yc_archive_progress_cb progress_cb,
    void *progress_userdata
);

int32_t yc_archive_extract(
    const char *archive_path,
    const char *destination_directory,
    const uint8_t *password,
    size_t password_length,
    yc_archive_control *control,
    yc_archive_progress_cb progress_cb,
    void *progress_userdata
);

const char *yc_archive_error_name(int32_t error_code);
void yc_archive_secure_zero(void *buffer, size_t length);

#ifdef __cplusplus
}
#endif

#endif
