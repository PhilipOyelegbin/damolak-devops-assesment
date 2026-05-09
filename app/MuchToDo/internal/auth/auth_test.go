package auth

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Falls back to a default value if not set (useful for local testing).
func getTestSecretKey() string {
	secret := os.Getenv("JWT_SECRET_KEY")
	return secret
}

// TestTokenService provides unit tests for the JWT token service.
func TestTokenService(t *testing.T) {
	// Setup: Initialize the service with a secret key from env
	secretKey := getTestSecretKey()
	expirationHours := 1
	tokenSvc := NewTokenService(secretKey, expirationHours)
	userID := "test-user-123"

	t.Run("Generate and Validate Token - Happy Path", func(t *testing.T) {
		token, err := tokenSvc.GenerateToken(userID)
		require.NoError(t, err)
		require.NotEmpty(t, token)

		validatedUserID, err := tokenSvc.ValidateToken(token)
		require.NoError(t, err)
		require.NotNil(t, validatedUserID)

		assert.Equal(t, userID, validatedUserID)
	})

	t.Run("Validate Token - Invalid Signature", func(t *testing.T) {
		// Use a different env-based or hardcoded secondary key
		otherSecret := "a-different-secret-key"
		otherTokenSvc := NewTokenService(otherSecret, expirationHours)

		token, err := otherTokenSvc.GenerateToken(userID)
		require.NoError(t, err)

		_, err = tokenSvc.ValidateToken(token)
		assert.Error(t, err)
	})

	t.Run("Validate Token - Malformed Token", func(t *testing.T) {
		_, err := tokenSvc.ValidateToken("this.is.not.a.valid.token")
		assert.Error(t, err)
	})

	t.Run("Validate Token - No Bearer Prefix", func(t *testing.T) {
		token, err := tokenSvc.GenerateToken(userID)
		require.NoError(t, err)

		_, err = tokenSvc.ValidateToken(token)
		assert.NoError(t, err)
	})
}