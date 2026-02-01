/**
 * Google Apps Script สำหรับ sync ข้อมูล Profile จาก Flutter App ไป Google Sheet
 *
 * วิธีติดตั้ง:
 * 1. เปิด Google Sheet: https://docs.google.com/spreadsheets/d/18C36anIrMP3qGIP1X-it0zjH0WyTJ4k-ra1RtbYWqE4
 * 2. ไปที่ Extensions > Apps Script
 * 3. ลบโค้ดเดิมทั้งหมด แล้ว copy โค้ดนี้ไปวาง
 * 4. บันทึก (Ctrl+S)
 * 5. Deploy > New deployment
 *    - เลือก Type: Web app
 *    - Execute as: Me
 *    - Who has access: Anyone
 * 6. คลิก Deploy และ copy URL ที่ได้มาใส่ใน Flutter app
 *
 * หมายเหตุ: ทุกครั้งที่แก้ไขโค้ด ต้อง Deploy ใหม่ (Deploy > Manage deployments > New version)
 */

// ชื่อ Sheet ที่เก็บข้อมูลพนักงาน (ตรวจสอบให้ตรงกับชื่อ tab ใน Google Sheet)
const SHEET_NAME = 'ฐานข้อมูลพนักงาน';

// Column mapping: ชื่อ field จาก Flutter -> Column index (A=1, B=2, ...)
// อิงจาก header row ที่ user ให้มา
const COLUMN_MAP = {
  'nickname': 2,           // B: ชื่อเล่น
  'prefix': 3,             // C: คำนำหน้า
  'full_name': 4,          // D: ชื่อ - นามสกุล
  'english_name': 5,       // E: English Name - Surname
  'dob': 6,                // F: วันเดือนปีเกิด
  'national_id': 7,        // G: เลขที่บัตรประจำตัวประชาชน
  'gender': 8,             // H: เพศ
  'weight': 9,             // I: น้ำหนัก
  'height': 10,            // J: ส่วนสูง
  'age': 11,               // K: อายุ (คำนวณอัตโนมัติ)
  'address': 12,           // L: อาศัยอยู่ที่
  'marital_status': 13,    // M: สถานภาพ
  'children_count': 14,    // N: จำนวนบุตร
  'disease': 15,           // O: โรคประจำตัว
  'phone': 16,             // P: เบอร์โทรศัพท์
  'education': 17,         // Q: ระดับการศึกษา
  'certification': 18,     // R: วุฒิบัตร/ประกาศณียบัตร ด้านการบริบาล
  'institution': 19,       // S: จากสถาบัน
  'skills': 20,            // T: ทักษะที่สามารถทำได้อย่างคล่องแคล่ว
  'work_experience': 21,   // U: ประสบการณ์ทำงาน
  'special_abilities': 22, // V: ความสามารถพิเศษอื่นๆ
  'certificate_url': 23,   // W: วุฒิบัตร/ประกาศณียบัตร (URL)
  'resume_url': 24,        // X: Resume (ถ้ามี)
  'id_card_url': 25,       // Y: สำเนาบัตรประจำตัวประชาชน
  'photo_url': 26,         // Z: รูปภาพหน้าตรงล่าสุด
  'email': 27,             // AA: ที่อยู่อีเมล
  'bank': 28,              // AB: ธนาคาร
  'bank_account': 29,      // AC: เลขบัญชี
  'bank_book_url': 30,     // AD: หน้าบุคแบงค์
};

// Column ที่ใช้เป็น unique identifier (เลขบัตรประชาชน)
const UNIQUE_ID_COLUMN = 7; // Column G

/**
 * รับ POST request จาก Flutter app
 * @param {Object} e - Event object จาก POST request
 * @returns {TextOutput} - JSON response
 */
function doPost(e) {
  try {
    // Parse JSON data จาก request body
    const data = JSON.parse(e.postData.contents);

    // Validate required field
    if (!data.national_id) {
      return createJsonResponse({
        success: false,
        error: 'Missing national_id (เลขบัตรประชาชน)'
      });
    }

    // เปิด Spreadsheet และ Sheet
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName(SHEET_NAME);

    if (!sheet) {
      return createJsonResponse({
        success: false,
        error: `Sheet "${SHEET_NAME}" not found. กรุณาตรวจสอบชื่อ tab ใน Google Sheet`
      });
    }

    // หา row ที่มีเลขบัตรประชาชนตรงกัน
    const existingRow = findRowByNationalId(sheet, data.national_id);

    if (existingRow) {
      // อัพเดท row ที่มีอยู่แล้ว
      updateRow(sheet, existingRow, data);
      return createJsonResponse({
        success: true,
        action: 'updated',
        row: existingRow,
        message: `อัพเดทข้อมูลแถวที่ ${existingRow} เรียบร้อย`
      });
    } else {
      // เพิ่ม row ใหม่
      const newRow = appendRow(sheet, data);
      return createJsonResponse({
        success: true,
        action: 'created',
        row: newRow,
        message: `เพิ่มข้อมูลแถวที่ ${newRow} เรียบร้อย`
      });
    }

  } catch (error) {
    return createJsonResponse({
      success: false,
      error: error.toString()
    });
  }
}

/**
 * รับ GET request (สำหรับทดสอบว่า script ทำงานไหม)
 */
function doGet(e) {
  return createJsonResponse({
    success: true,
    message: 'Irene Profile Sync API is running!',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
}

/**
 * หา row ที่มีเลขบัตรประชาชนตรงกัน
 * @param {Sheet} sheet - Google Sheet object
 * @param {string} nationalId - เลขบัตรประชาชน
 * @returns {number|null} - Row number หรือ null ถ้าไม่เจอ
 */
function findRowByNationalId(sheet, nationalId) {
  const data = sheet.getDataRange().getValues();

  // เริ่มจาก row 2 (skip header)
  for (let i = 1; i < data.length; i++) {
    // เปรียบเทียบเลขบัตรประชาชน (column G = index 6)
    const cellValue = String(data[i][UNIQUE_ID_COLUMN - 1]).trim();
    const searchValue = String(nationalId).trim();

    if (cellValue === searchValue) {
      return i + 1; // Row number (1-indexed)
    }
  }

  return null;
}

/**
 * อัพเดทข้อมูลใน row ที่มีอยู่แล้ว
 * ⚠️ สำคัญ: จะอัพเดทเฉพาะ field ที่มีค่า (ไม่ใช่ null/undefined/empty string)
 * ถ้า field เป็น null หรือ empty จะไม่ไปทับข้อมูลเดิมที่มีอยู่แล้ว
 *
 * @param {Sheet} sheet - Google Sheet object
 * @param {number} row - Row number
 * @param {Object} data - ข้อมูลที่จะอัพเดท
 */
function updateRow(sheet, row, data) {
  // Loop ผ่าน column mapping และอัพเดทเฉพาะ field ที่มีค่าจริงๆ
  for (const [field, col] of Object.entries(COLUMN_MAP)) {
    // ตรวจสอบว่ามี field นี้ และมีค่าจริงๆ (ไม่ใช่ null, undefined, หรือ empty string)
    if (data.hasOwnProperty(field) && hasValue(data[field])) {
      const value = formatValue(field, data[field]);
      sheet.getRange(row, col).setValue(value);
    }
    // ถ้าไม่มีค่า จะไม่ทำอะไร (ข้อมูลเดิมจะยังคงอยู่)
  }

  // คำนวณอายุจากวันเกิด (ถ้ามี)
  if (data.dob && hasValue(data.dob)) {
    const age = calculateAge(data.dob);
    sheet.getRange(row, COLUMN_MAP['age']).setValue(age);
  }
}

/**
 * ตรวจสอบว่าค่ามี "ค่าจริง" หรือไม่
 * - null, undefined → false
 * - empty string '' → false
 * - string ที่มีแต่ whitespace → false
 * - empty array [] → false
 * - 0 (number) → true (เพราะ 0 อาจเป็นค่าที่ถูกต้อง เช่น จำนวนบุตร = 0)
 *
 * @param {*} value - ค่าที่จะตรวจสอบ
 * @returns {boolean} - true ถ้ามีค่าจริง
 */
function hasValue(value) {
  // null หรือ undefined
  if (value === null || value === undefined) {
    return false;
  }

  // empty string หรือ whitespace only
  if (typeof value === 'string' && value.trim() === '') {
    return false;
  }

  // empty array
  if (Array.isArray(value) && value.length === 0) {
    return false;
  }

  // อื่นๆ ถือว่ามีค่า (รวม 0, false ด้วย เพราะอาจเป็นค่าที่ถูกต้อง)
  return true;
}

/**
 * เพิ่ม row ใหม่
 * @param {Sheet} sheet - Google Sheet object
 * @param {Object} data - ข้อมูลที่จะเพิ่ม
 * @returns {number} - Row number ที่เพิ่มใหม่
 */
function appendRow(sheet, data) {
  const lastRow = sheet.getLastRow();
  const newRow = lastRow + 1;

  // Loop ผ่าน column mapping และใส่ค่า
  for (const [field, col] of Object.entries(COLUMN_MAP)) {
    if (data.hasOwnProperty(field) && data[field] !== null && data[field] !== undefined) {
      const value = formatValue(field, data[field]);
      sheet.getRange(newRow, col).setValue(value);
    }
  }

  // คำนวณอายุจากวันเกิด (ถ้ามี)
  if (data.dob) {
    const age = calculateAge(data.dob);
    sheet.getRange(newRow, COLUMN_MAP['age']).setValue(age);
  }

  return newRow;
}

/**
 * Format ค่าก่อนใส่ใน Sheet
 * @param {string} field - ชื่อ field
 * @param {*} value - ค่าที่จะ format
 * @returns {*} - ค่าที่ format แล้ว
 */
function formatValue(field, value) {
  // แปลง skills array เป็น string
  if (field === 'skills' && Array.isArray(value)) {
    return value.join(', ');
  }

  // แปลงวันที่เป็น format ที่อ่านง่าย
  if (field === 'dob' && value) {
    try {
      const date = new Date(value);
      if (!isNaN(date.getTime())) {
        // Format: DD/MM/YYYY
        const day = String(date.getDate()).padStart(2, '0');
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const year = date.getFullYear();
        return `${day}/${month}/${year}`;
      }
    } catch (e) {
      // Return original value if parsing fails
    }
  }

  return value;
}

/**
 * คำนวณอายุจากวันเกิด
 * @param {string} dob - วันเกิด (ISO format)
 * @returns {number} - อายุ (ปี)
 */
function calculateAge(dob) {
  try {
    const birthDate = new Date(dob);
    const today = new Date();

    let age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();

    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
      age--;
    }

    return age;
  } catch (e) {
    return '';
  }
}

/**
 * สร้าง JSON response
 * @param {Object} data - ข้อมูลที่จะส่งกลับ
 * @returns {TextOutput} - JSON response
 */
function createJsonResponse(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * ฟังก์ชันสำหรับทดสอบ (รันได้จาก Apps Script Editor)
 */
function testSync() {
  const testData = {
    national_id: '1234567890123',
    nickname: 'ทดสอบ',
    prefix: 'นาย',
    full_name: 'ทดสอบ ระบบ',
    english_name: 'Test System',
    dob: '1990-05-15',
    gender: 'ชาย',
    weight: 65,
    height: 175,
    address: '123 หมู่ 1 ต.ทดสอบ อ.ทดสอบ จ.ทดสอบ 10000',
    marital_status: 'โสด',
    children_count: 0,
    disease: '',
    phone: '0812345678',
    education: 'ปริญญาตรี',
    certification: 'ผู้ช่วยเหลือดูแลผู้สูงอายุ (CG)',
    institution: 'สถาบันทดสอบ',
    skills: ['ดูแลสุขอนามัยส่วนบุคคล', 'ดูแลการรับประทานอาหาร'],
    work_experience: 'ทดสอบ 2 ปี',
    special_abilities: 'ทำอาหาร',
    bank: 'กสิกรไทย',
    bank_account: '1234567890'
  };

  // Mock POST event
  const mockEvent = {
    postData: {
      contents: JSON.stringify(testData)
    }
  };

  const result = doPost(mockEvent);
  Logger.log(result.getContent());
}