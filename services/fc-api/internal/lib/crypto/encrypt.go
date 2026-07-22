package crypto

import (
    "crypto/aes"
    "crypto/cipher"
    "crypto/rand"
    "crypto/sha256"
    "encoding/base64"
    "errors"
    "io"
)

// Encrypt encrypts plaintext using AES-GCM with a key derived from secret.
func Encrypt(plaintext, secret string) (string, error) {
    if plaintext == "" {
        return "", nil
    }
    key := sha256.Sum256([]byte(secret))
    block, err := aes.NewCipher(key[:])
    if err != nil {
        return "", err
    }
    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return "", err
    }
    nonce := make([]byte, gcm.NonceSize())
    if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
        return "", err
    }
    ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil)
    return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// Decrypt decrypts ciphertext encrypted with Encrypt.
func Decrypt(ciphertext, secret string) (string, error) {
    if ciphertext == "" {
        return "", nil
    }
    data, err := base64.StdEncoding.DecodeString(ciphertext)
    if err != nil {
        return "", err
    }
    key := sha256.Sum256([]byte(secret))
    block, err := aes.NewCipher(key[:])
    if err != nil {
        return "", err
    }
    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return "", err
    }
    if len(data) < gcm.NonceSize() {
        return "", errors.New("ciphertext too short")
    }
    nonce, ct := data[:gcm.NonceSize()], data[gcm.NonceSize():]
    plaintext, err := gcm.Open(nil, nonce, ct, nil)
    if err != nil {
        return "", err
    }
    return string(plaintext), nil
}