/**
 * Recipe utility functions
 */

/**
 * Cleans recipe descriptions by removing "Try" sections that link to similar recipes.
 * These sections often contain broken links and are not useful.
 * 
 * @param {string} description - The recipe description to clean
 * @returns {string} - The cleaned description
 */
function cleanRecipeDescription(description) {
	if (!description || typeof description !== 'string') {
		return description || '';
	}

	// Remove HTML tags first (common in descriptions from APIs)
	let cleaned = description.replace(/<[^>]*>/g, '');

	// Patterns to match sections that should be removed:
	// 1. "Try" sections - variations like "Try this recipe", "Try these similar recipes", etc.
	// 2. "Users who liked" sections - "Users who liked this recipe also liked..."
	// 3. "Similar recipes" sections - "Similar recipes include..."
	// 4. "You might also like" sections
	// 5. "Related recipes" sections
	// 6. "If you like this recipe" sections - "If you like this recipe, take a look at these similar recipes..."
	const patterns = [
		// Try patterns
		/\b[Tt]ry\s+(?:this|these|similar|it|a|an|the)?\s*(?:recipe|recipes|dish|dishes|variation|variations|version|versions|with|out)?/i,
		// Users who liked patterns
		/\b[Uu]sers?\s+who\s+(?:liked|loved|enjoyed|tried)\s+(?:this\s+)?(?:recipe|dish)?\s+(?:also\s+)?(?:liked|loved|enjoyed|tried)/i,
		// Similar/Related recipes patterns
		/\b(?:Similar|Related|Other)\s+(?:recipes?|dishes?)\s+(?:include|are|you\s+might\s+also\s+like)/i,
		// You might also like patterns
		/\b[Yy]ou\s+might\s+(?:also\s+)?(?:like|enjoy|try)/i,
		// Check out patterns
		/\b[Cc]heck\s+out\s+(?:these|this|other|similar|related)\s+(?:recipes?|dishes?)?/i,
		// If you like this recipe patterns
		/\b[Ii]f\s+you\s+like\s+(?:this\s+)?(?:recipe|dish)/i,
	];

	// Find the earliest match position
	let earliestMatch = -1;
	for (const pattern of patterns) {
		const match = cleaned.search(pattern);
		if (match !== -1) {
			if (earliestMatch === -1 || match < earliestMatch) {
				earliestMatch = match;
			}
		}
	}

	if (earliestMatch !== -1) {
		// Remove everything from the earliest match onwards
		cleaned = cleaned.substring(0, earliestMatch).trim();
	}

	// Clean up any trailing punctuation or whitespace
	cleaned = cleaned.replace(/\s+$/, '').replace(/[.,;:]+$/, '');

	return cleaned;
}

module.exports = {
	cleanRecipeDescription,
};

