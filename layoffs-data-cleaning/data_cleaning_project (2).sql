-- ============================================
-- PROJECT: Data Cleaning - Layoffs Dataset
-- Author: [Your Name]
-- Date: [Current Date]
-- ============================================
-- Cleaning Steps:
-- 1. Remove duplicates
-- 2. Standardize the data
-- 3. Handle null values and blanks
-- 4. Remove unnecessary rows and columns
-- ============================================

SELECT *
FROM layoffs;

-- ============================================
-- CREATE STAGING TABLE
-- ============================================
-- Create a copy to preserve original data
CREATE TABLE layoffs_staging
LIKE layoffs;

INSERT INTO layoffs_staging
SELECT *
FROM layoffs;

-- ============================================
-- REMOVE DUPLICATES
-- ============================================

-- Identify duplicates using ROW_NUMBER()
WITH duplicate_cte AS (
    SELECT *,
        ROW_NUMBER() OVER(
            PARTITION BY company, location, industry, total_laid_off, 
                         percentage_laid_off, `date`, stage, country, 
                         funds_raised_millions
        ) AS row_num
    FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

-- Create new staging table with row_num column to enable deletion
CREATE TABLE `layoffs_staging2` (
    `company` TEXT,
    `location` TEXT,
    `industry` TEXT,
    `total_laid_off` INT DEFAULT NULL,
    `percentage_laid_off` TEXT,
    `date` TEXT,
    `stage` TEXT,
    `country` TEXT,
    `funds_raised_millions` INT DEFAULT NULL,
    `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO layoffs_staging2
SELECT *,
    ROW_NUMBER() OVER(
        PARTITION BY company, location, industry, total_laid_off, 
                     percentage_laid_off, `date`, stage, country, 
                     funds_raised_millions
    ) AS row_num
FROM layoffs_staging;

-- Delete duplicates
DELETE
FROM layoffs_staging2
WHERE row_num > 1;

-- ============================================
-- STANDARDIZE DATA
-- ============================================

-- Trim whitespace from company names
UPDATE layoffs_staging2
SET company = TRIM(company);

-- Standardize industry names
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- Fix location encoding issues
UPDATE layoffs_staging2
SET location = CASE
    WHEN location = 'DÃ¼sseldorf' THEN 'Dusseldorf'
    WHEN location = 'MalmÃ¶' THEN 'Malmo'
    WHEN location = 'FlorianÃ³polis' THEN 'Florianopolis'
    ELSE location
END
WHERE location IN ('DÃ¼sseldorf', 'MalmÃ¶', 'FlorianÃ³polis');

-- Remove trailing periods from country names
UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- Convert date to proper DATE format
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- ============================================
-- HANDLE NULL VALUES
-- ============================================

-- Convert blank strings to NULL
UPDATE layoffs_staging2
SET industry = NULL 
WHERE industry = '';

-- Fill missing industries using self-join
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
    ON t1.company = t2.company
    AND t1.location = t2.location
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- ============================================
-- REMOVE UNUSABLE ROWS
-- ============================================

-- Delete rows with no layoff data
DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

-- Remove temporary row_num column
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

-- ============================================
-- FINAL RESULT
-- ============================================

SELECT *
FROM layoffs_staging2;