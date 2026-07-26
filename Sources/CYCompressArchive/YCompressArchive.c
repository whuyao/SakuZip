#include "YCompressArchive.h"

#include "mz.h"
#include "mz_strm.h"
#include "mz_zip.h"
#include "mz_zip_rw.h"

#include <ctype.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

struct yc_archive_control {
    pthread_mutex_t mutex;
    pthread_cond_t condition;
    int paused;
    int cancelled;
};

typedef struct yc_progress_context {
    yc_archive_control *control;
    yc_archive_progress_cb callback;
    void *userdata;
    uint64_t total_bytes;
    uint64_t completed_bytes;
    uint64_t current_entry_bytes;
    const char *current_entry_name;
} yc_progress_context;

void yc_archive_secure_zero(void *buffer, size_t length) {
    if (!buffer || length == 0)
        return;
#if defined(__STDC_LIB_EXT1__)
    memset_s(buffer, length, 0, length);
#else
    volatile uint8_t *bytes = (volatile uint8_t *)buffer;
    while (length-- > 0)
        *bytes++ = 0;
#endif
}

static char *yc_password_copy(const uint8_t *password, size_t length) {
    char *copy = NULL;
    if (!password || length == 0)
        return NULL;
    copy = (char *)calloc(length + 1, 1);
    if (!copy)
        return NULL;
    memcpy(copy, password, length);
    copy[length] = 0;
    return copy;
}

static void yc_password_delete(char **password, size_t length) {
    if (!password || !*password)
        return;
    yc_archive_secure_zero(*password, length + 1);
    free(*password);
    *password = NULL;
}

yc_archive_control *yc_archive_control_create(void) {
    yc_archive_control *control = (yc_archive_control *)calloc(1, sizeof(yc_archive_control));
    if (!control)
        return NULL;
    pthread_mutex_init(&control->mutex, NULL);
    pthread_cond_init(&control->condition, NULL);
    return control;
}

void yc_archive_control_delete(yc_archive_control **control) {
    yc_archive_control *value = NULL;
    if (!control || !*control)
        return;
    value = *control;
    pthread_mutex_lock(&value->mutex);
    value->cancelled = 1;
    value->paused = 0;
    pthread_cond_broadcast(&value->condition);
    pthread_mutex_unlock(&value->mutex);
    pthread_cond_destroy(&value->condition);
    pthread_mutex_destroy(&value->mutex);
    yc_archive_secure_zero(value, sizeof(*value));
    free(value);
    *control = NULL;
}

void yc_archive_control_set_paused(yc_archive_control *control, int paused) {
    if (!control)
        return;
    pthread_mutex_lock(&control->mutex);
    control->paused = paused ? 1 : 0;
    if (!control->paused)
        pthread_cond_broadcast(&control->condition);
    pthread_mutex_unlock(&control->mutex);
}

void yc_archive_control_cancel(yc_archive_control *control) {
    if (!control)
        return;
    pthread_mutex_lock(&control->mutex);
    control->cancelled = 1;
    control->paused = 0;
    pthread_cond_broadcast(&control->condition);
    pthread_mutex_unlock(&control->mutex);
}

static int32_t yc_archive_control_wait(yc_archive_control *control) {
    int cancelled = 0;
    if (!control)
        return MZ_OK;
    pthread_mutex_lock(&control->mutex);
    while (control->paused && !control->cancelled)
        pthread_cond_wait(&control->condition, &control->mutex);
    cancelled = control->cancelled;
    pthread_mutex_unlock(&control->mutex);
    return cancelled ? YC_ARCHIVE_CANCELLED : MZ_OK;
}

static int yc_is_unsafe_entry(const char *entry) {
    const char *cursor = entry;
    const char *component = entry;
    size_t component_length = 0;
    if (!entry || !*entry)
        return 1;
    if (entry[0] == '/' || entry[0] == '\\' || entry[0] == '~')
        return 1;
    if (isalpha((unsigned char)entry[0]) && entry[1] == ':')
        return 1;
    while (1) {
        if (*cursor == '/' || *cursor == '\\' || *cursor == 0) {
            component_length = (size_t)(cursor - component);
            if (component_length == 2 && component[0] == '.' && component[1] == '.')
                return 1;
            if (*cursor == 0)
                break;
            component = cursor + 1;
        }
        cursor++;
    }
    return 0;
}

int32_t yc_archive_inspect(
    const char *archive_path,
    yc_archive_info *info,
    char *unsafe_entry,
    size_t unsafe_entry_capacity
) {
    void *reader = NULL;
    mz_zip_file *file_info = NULL;
    int32_t error = MZ_OK;
    if (!archive_path || !info)
        return MZ_PARAM_ERROR;
    memset(info, 0, sizeof(*info));
    if (unsafe_entry && unsafe_entry_capacity > 0)
        unsafe_entry[0] = 0;

    reader = mz_zip_reader_create();
    if (!reader)
        return MZ_MEM_ERROR;
    error = mz_zip_reader_open_file(reader, archive_path);
    if (error != MZ_OK)
        goto cleanup;
    error = mz_zip_reader_goto_first_entry(reader);
    if (error == MZ_END_OF_LIST) {
        error = MZ_OK;
        goto cleanup;
    }
    while (error == MZ_OK) {
        error = mz_zip_reader_entry_get_info(reader, &file_info);
        if (error != MZ_OK)
            break;
        if (yc_is_unsafe_entry(file_info->filename)) {
            if (unsafe_entry && unsafe_entry_capacity > 0) {
                strncpy(unsafe_entry, file_info->filename, unsafe_entry_capacity - 1);
                unsafe_entry[unsafe_entry_capacity - 1] = 0;
            }
            error = YC_ARCHIVE_UNSAFE_ENTRY;
            break;
        }
        info->entry_count += 1;
        if (file_info->uncompressed_size > 0)
            info->total_uncompressed_size += (uint64_t)file_info->uncompressed_size;
        if ((file_info->flag & MZ_ZIP_FLAG_ENCRYPTED) != 0) {
            info->is_encrypted = 1;
            if (file_info->aes_version != 0 || file_info->compression_method == MZ_COMPRESS_METHOD_AES)
                info->uses_aes = 1;
            else
                info->uses_traditional_encryption = 1;
        }
        error = mz_zip_reader_goto_next_entry(reader);
    }
    if (error == MZ_END_OF_LIST)
        error = MZ_OK;

cleanup:
    if (reader) {
        mz_zip_reader_close(reader);
        mz_zip_reader_delete(&reader);
    }
    return error;
}

static int32_t yc_progress_update(
    yc_progress_context *context,
    int64_t position,
    const char *entry_name
) {
    double progress = 0;
    int32_t control_error = yc_archive_control_wait(context->control);
    if (control_error != MZ_OK)
        return control_error;
    if (context->total_bytes > 0) {
        progress = (double)(context->completed_bytes + (position > 0 ? (uint64_t)position : 0))
            / (double)context->total_bytes;
    }
    if (progress > 1)
        progress = 1;
    if (context->callback)
        context->callback(progress, entry_name ? entry_name : context->current_entry_name, context->userdata);
    return MZ_OK;
}

static int32_t yc_writer_entry_cb(
    void *handle,
    void *userdata,
    mz_zip_file *file_info
) {
    yc_progress_context *context = (yc_progress_context *)userdata;
    (void)handle;
    context->completed_bytes += context->current_entry_bytes;
    context->current_entry_bytes =
        file_info->uncompressed_size > 0 ? (uint64_t)file_info->uncompressed_size : 0;
    context->current_entry_name = file_info->filename;
    return yc_progress_update(context, 0, file_info->filename);
}

static int32_t yc_writer_progress_cb(
    void *handle,
    void *userdata,
    mz_zip_file *file_info,
    int64_t position
) {
    (void)handle;
    return yc_progress_update(
        (yc_progress_context *)userdata,
        position,
        file_info ? file_info->filename : NULL
    );
}

static int32_t yc_reader_entry_cb(
    void *handle,
    void *userdata,
    mz_zip_file *file_info,
    const char *path
) {
    yc_progress_context *context = (yc_progress_context *)userdata;
    (void)handle;
    (void)path;
    context->completed_bytes += context->current_entry_bytes;
    context->current_entry_bytes =
        file_info->uncompressed_size > 0 ? (uint64_t)file_info->uncompressed_size : 0;
    context->current_entry_name = file_info->filename;
    return yc_progress_update(context, 0, file_info->filename);
}

static int32_t yc_reader_progress_cb(
    void *handle,
    void *userdata,
    mz_zip_file *file_info,
    int64_t position
) {
    (void)handle;
    return yc_progress_update(
        (yc_progress_context *)userdata,
        position,
        file_info ? file_info->filename : NULL
    );
}

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
) {
    void *writer = NULL;
    char *password_copy = NULL;
    char *root_path = NULL;
    const char *slash = NULL;
    yc_progress_context progress = {0};
    int32_t error = MZ_OK;
    if (!source_path || !destination_path)
        return MZ_PARAM_ERROR;
    if (encryption_mode != YC_ARCHIVE_ENCRYPTION_NONE && (!password || password_length == 0))
        return YC_ARCHIVE_PASSWORD_REQUIRED;

    password_copy = yc_password_copy(password, password_length);
    if (password_length > 0 && !password_copy)
        return MZ_MEM_ERROR;
    writer = mz_zip_writer_create();
    if (!writer) {
        error = MZ_MEM_ERROR;
        goto cleanup;
    }
    progress.control = control;
    progress.callback = progress_cb;
    progress.userdata = progress_userdata;
    progress.total_bytes = total_uncompressed_size > 0 ? total_uncompressed_size : 1;

    mz_zip_writer_set_compress_method(writer, MZ_COMPRESS_METHOD_DEFLATE);
    mz_zip_writer_set_compress_level(writer, (int16_t)compression_level);
    mz_zip_writer_set_store_links(writer, 1);
    mz_zip_writer_set_follow_links(writer, 0);
    mz_zip_writer_set_progress_interval(writer, 80);
    mz_zip_writer_set_entry_cb(writer, &progress, yc_writer_entry_cb);
    mz_zip_writer_set_progress_cb(writer, &progress, yc_writer_progress_cb);
    if (encryption_mode != YC_ARCHIVE_ENCRYPTION_NONE) {
        mz_zip_writer_set_password(writer, password_copy);
        mz_zip_writer_set_aes(writer, encryption_mode == YC_ARCHIVE_ENCRYPTION_AES256 ? 1 : 0);
    }
    error = mz_zip_writer_open_file(writer, destination_path, 0, 0);
    if (error != MZ_OK)
        goto cleanup;

    if (keep_parent_folder) {
        slash = strrchr(source_path, '/');
        if (slash) {
            size_t root_length = (size_t)(slash - source_path);
            root_path = (char *)calloc(root_length + 1, 1);
            if (!root_path) {
                error = MZ_MEM_ERROR;
                goto cleanup;
            }
            memcpy(root_path, source_path, root_length);
            root_path[root_length] = 0;
        }
    }
    error = mz_zip_writer_add_path(
        writer,
        source_path,
        root_path ? root_path : source_path,
        0,
        1
    );
    if (error == MZ_OK)
        error = mz_zip_writer_close(writer);

cleanup:
    if (writer)
        mz_zip_writer_delete(&writer);
    if (progress_cb && error == MZ_OK)
        progress_cb(1, progress.current_entry_name, progress_userdata);
    if (root_path)
        free(root_path);
    yc_password_delete(&password_copy, password_length);
    return error;
}

int32_t yc_archive_extract(
    const char *archive_path,
    const char *destination_directory,
    const uint8_t *password,
    size_t password_length,
    yc_archive_control *control,
    yc_archive_progress_cb progress_cb,
    void *progress_userdata
) {
    void *reader = NULL;
    char *password_copy = NULL;
    yc_archive_info info;
    yc_progress_context progress = {0};
    int32_t error = MZ_OK;
    if (!archive_path || !destination_directory)
        return MZ_PARAM_ERROR;
    error = yc_archive_inspect(archive_path, &info, NULL, 0);
    if (error != MZ_OK)
        return error;
    if (info.is_encrypted && (!password || password_length == 0))
        return YC_ARCHIVE_PASSWORD_REQUIRED;
    password_copy = yc_password_copy(password, password_length);
    if (password_length > 0 && !password_copy)
        return MZ_MEM_ERROR;
    reader = mz_zip_reader_create();
    if (!reader) {
        error = MZ_MEM_ERROR;
        goto cleanup;
    }
    progress.control = control;
    progress.callback = progress_cb;
    progress.userdata = progress_userdata;
    progress.total_bytes = info.total_uncompressed_size > 0 ? info.total_uncompressed_size : 1;
    mz_zip_reader_set_progress_interval(reader, 80);
    mz_zip_reader_set_entry_cb(reader, &progress, yc_reader_entry_cb);
    mz_zip_reader_set_progress_cb(reader, &progress, yc_reader_progress_cb);
    if (password_copy)
        mz_zip_reader_set_password(reader, password_copy);
    error = mz_zip_reader_open_file(reader, archive_path);
    if (error != MZ_OK)
        goto cleanup;
    error = mz_zip_reader_save_all(reader, destination_directory);
    if (error == MZ_OK)
        error = mz_zip_reader_close(reader);

cleanup:
    if (reader)
        mz_zip_reader_delete(&reader);
    if (progress_cb && error == MZ_OK)
        progress_cb(1, progress.current_entry_name, progress_userdata);
    yc_password_delete(&password_copy, password_length);
    return error;
}

const char *yc_archive_error_name(int32_t error_code) {
    switch (error_code) {
    case YC_ARCHIVE_OK: return "ok";
    case YC_ARCHIVE_CANCELLED: return "cancelled";
    case YC_ARCHIVE_UNSAFE_ENTRY: return "unsafe-entry";
    case YC_ARCHIVE_PASSWORD_REQUIRED: return "password-required";
    case MZ_PASSWORD_ERROR: return "incorrect-password";
    case MZ_CRYPT_ERROR: return "crypt-error";
    case MZ_SUPPORT_ERROR: return "unsupported";
    case MZ_FORMAT_ERROR: return "invalid-format";
    case MZ_CRC_ERROR: return "integrity-error";
    case MZ_OPEN_ERROR: return "open-error";
    case MZ_WRITE_ERROR: return "write-error";
    case MZ_READ_ERROR: return "read-error";
    default: return "archive-error";
    }
}
